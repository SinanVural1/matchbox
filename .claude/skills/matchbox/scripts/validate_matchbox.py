#!/usr/bin/env python3
"""
Static cross-check for a Matchbox shader pair (<name>.glsl + <name>.xml).

Catches the class of bug that makes Flame fail silently or report only
CProcessShader::RenderFrame::CreateRenderGraph:

  - uniform declared in one file but not the other
  - sampler not bound to an input in the XML
  - two controls assigned the same Page/Row/Col slot
  - a control placed in a column the XML never declares
  - GLSL reserved words used as variable names
  - unbalanced braces or parens

It does NOT compile the shader. Only Flame can confirm that.

Usage:
    python3 validate_matchbox.py <path/to/name | name>
    python3 validate_matchbox.py --all [directory]

A bare name with no path, such as sv_Hypot, is looked up as
shaders/<name>/<name>, then wip/<name>/<name>, when it isn't
found as given. --all searches the directory and everything below it,
so --all shaders checks every finished shader and --all wip the
unfinished ones. Multi-pass shaders (name.01.glsl, name.02.glsl...) are listed
but not checked.

Exit status is 0 when every checked shader passes, 1 otherwise.
"""

import re
import sys
import os
import glob
import xml.etree.ElementTree as ET
from collections import Counter

# Reserved in GLSL, and plausible as a variable name in image-processing code.
RESERVED = [
    "out", "in", "inout", "half", "sample", "filter", "layout",
    "double", "fixed", "input", "output", "active", "common",
    "partition", "patch", "resource", "superp",
]

MAX_ROWS_PER_COL = 6


def strip_comments(src):
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    return re.sub(r"//.*", "", src)


def check(basename):
    glsl_path = basename + ".glsl"
    xml_path = basename + ".xml"
    name = os.path.basename(basename)

    problems = []
    notes = []

    for p in (glsl_path, xml_path):
        if not os.path.isfile(p):
            problems.append("missing file: %s" % p)
    if problems:
        return problems, notes

    src = strip_comments(open(glsl_path, encoding="utf-8").read())
    raw_xml = open(xml_path, encoding="utf-8").read()

    # ---- XML parses at all ----
    try:
        root = ET.parse(xml_path).getroot()
    except ET.ParseError as e:
        return ["XML does not parse: %s" % e], notes

    # ---- gather names ----
    glsl_all = set(re.findall(r"uniform\s+\w+\s+(\w+)\s*;", src))
    glsl_samplers = set(re.findall(r"uniform\s+sampler2D\s+(\w+)\s*;", src))
    glsl_scalars = {u for u in glsl_all - glsl_samplers
                    if not u.startswith("adsk_")}

    xml_uniforms = list(root.iter("Uniform"))
    xml_samplers = {u.get("Name") for u in xml_uniforms
                    if u.get("Type") == "sampler2D"}
    xml_scalars = {u.get("Name") for u in xml_uniforms
                   if u.get("Type") != "sampler2D"}

    for n in sorted(glsl_scalars - xml_scalars):
        problems.append("uniform '%s' declared in GLSL but absent from XML "
                        "(control will never appear)" % n)
    for n in sorted(xml_scalars - glsl_scalars):
        problems.append("uniform '%s' declared in XML but absent from GLSL" % n)

    if glsl_samplers != xml_samplers:
        problems.append("sampler mismatch: GLSL has %s, XML has %s"
                        % (sorted(glsl_samplers) or "none",
                           sorted(xml_samplers) or "none"))

    # ---- input declaration shape ----
    if re.search(r"<\s*Texture\b", raw_xml):
        problems.append("<Texture> element present: inputs are declared as "
                        "<Uniform Type=\"sampler2D\" InputType=\"Front\">")

    for u in xml_uniforms:
        if u.get("Type") == "sampler2D" and not u.get("InputType"):
            problems.append("sampler '%s' has no InputType attribute"
                            % u.get("Name"))

    selfclosing = re.findall(r"<Uniform\b[^>]*/>", raw_xml)
    if selfclosing:
        problems.append("%d self-closing <Uniform .../> element(s): each needs "
                        "an explicit </Uniform>" % len(selfclosing))

    # ---- root attributes ----
    for attr in ("Name", "ShaderType"):
        if not root.get(attr):
            problems.append("<ShaderNodePreset> missing required attribute "
                            "'%s'" % attr)

    # ---- ToolTip spelling ----
    for u in xml_uniforms:
        for a in u.attrib:
            if a.lower() == "tooltip" and a != "ToolTip":
                problems.append("uniform '%s' uses '%s'; the attribute is "
                                "'ToolTip'" % (u.get("Name"), a))

    # ---- bool defaults ----
    for u in xml_uniforms:
        if u.get("Type") == "bool":
            d = u.get("Default")
            if d not in ("True", "False"):
                problems.append("bool '%s' has Default=\"%s\"; expected "
                                "\"True\" or \"False\"" % (u.get("Name"), d))

    # ---- layout ----
    slots = Counter()
    for u in xml_uniforms:
        if u.get("Type") == "sampler2D":
            continue
        page, col, row = u.get("Page"), u.get("Col"), u.get("Row")
        if page is None or col is None or row is None:
            problems.append("uniform '%s' is missing Page/Row/Col (a uniform "
                            "without Page renders an empty tab)" % u.get("Name"))
            continue
        slots[(page, col, row)] += 1

    for slot, n in sorted(slots.items()):
        if n > 1:
            problems.append("%d controls share Page %s Col %s Row %s"
                            % (n, slot[0], slot[1], slot[2]))

    declared_cols = {(c.get("Page"), c.get("Col")) for c in root.iter("Col")}
    used_cols = {(p, c) for (p, c, r) in slots}
    for pc in sorted(used_cols - declared_cols):
        problems.append("Page %s Col %s used but not declared in a <Page> block"
                        % pc)

    declared_pages = {p.get("Page") for p in root.iter("Page")}
    used_pages = {p for (p, c, r) in slots}
    for pg in sorted(used_pages - declared_pages):
        problems.append("Page %s used but has no <Page> element" % pg)

    percol = Counter((p, c) for (p, c, r) in slots)
    for (p, c), n in sorted(percol.items()):
        if n > MAX_ROWS_PER_COL:
            notes.append("Page %s Col %s has %d rows (keep to about %d)"
                         % (p, c, n, MAX_ROWS_PER_COL))

    # ---- GLSL hazards ----
    for kw in RESERVED:
        if re.search(r"\b(float|int|vec[234]|bool|mat[234]|uint)\s+"
                     + kw + r"\b", src):
            problems.append("reserved word '%s' used as a variable name "
                            "(will not compile)" % kw)

    if src.count("{") != src.count("}"):
        problems.append("unbalanced braces in GLSL")
    if src.count("(") != src.count(")"):
        problems.append("unbalanced parens in GLSL")

    if not re.search(r"\bvoid\s+main\s*\(", src):
        problems.append("no main() found in GLSL")

    for d in ("adsk_input1_w", "adsk_input1_h"):
        if d in src:
            problems.append("%s is not part of the Matchbox API; use "
                            "adsk_result_w/h" % d)

    return problems, notes


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2

    if args[0] == "--all":
        directory = args[1] if len(args) > 1 else "."
        found = sorted(glob.glob(os.path.join(directory, "**", "*.glsl"),
                                 recursive=True))
        targets = []
        for p in found:
            base = os.path.splitext(p)[0]
            # Pass files of a multi-pass shader are name.01.glsl etc. with one
            # shared name.xml; check() only understands single-pass pairs.
            if re.search(r"\.\d\d$", base):
                print("skip  %s (multi-pass, not checked)" % os.path.basename(p))
                continue
            targets.append(base)
        if not targets:
            print("no .glsl files found in %s" % directory)
            return 1
    else:
        targets = []
        for a in args:
            t = os.path.splitext(a)[0] if a.endswith((".glsl", ".xml")) else a
            if not os.path.isfile(t + ".glsl") and os.sep not in t:
                for top in ("shaders", "wip"):
                    guess = os.path.join(top, t, t)
                    if os.path.isfile(guess + ".glsl"):
                        t = guess
                        break
            targets.append(t)

    failed = 0
    for t in targets:
        problems, notes = check(t)
        label = os.path.basename(t)
        if problems:
            failed += 1
            print("FAIL  %s" % label)
            for p in problems:
                print("      - %s" % p)
        else:
            print("ok    %s" % label)
        for n in notes:
            print("      note: %s" % n)

    if failed:
        print("\n%d of %d failed." % (failed, len(targets)))
    else:
        print("\n%d checked, all passed. Static checks only — "
              "load in Flame to confirm it compiles." % len(targets))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

# Matchbox Shader Skill — Autodesk Flame

This reference has moved into the `matchbox` Claude Code skill, split by topic. This file stays so existing links keep working.

- [SKILL.md](.claude/skills/matchbox/SKILL.md): the rules that make shaders fail silently, the GLSL dialect, debugging, UI conventions and pitfalls
- [XML schema](.claude/skills/matchbox/reference/xml-schema.md): root element, inputs, every control type, layout, conditional UI, `ResDependent`, `MatteProvider`
- [GLSL dialect](.claude/skills/matchbox/reference/glsl-dialect.md): file structure, legacy vs modern style, the `adsk_` API, anti-aliasing and shared building blocks
- [Multi-pass and mipmaps](.claude/skills/matchbox/reference/multipass.md): passes and their file naming, `Duplicate`, bit depths, `NbExecutions`, mip levels, render targets
- [Advanced features](.claude/skills/matchbox/reference/advanced.md): temporal accumulation and sampling, transitions, Action lights, UI-only shaders
- [Testing](.claude/skills/matchbox/reference/testing.md): validator, WebGL harness, what only Flame can confirm
- [Preview icons](.claude/skills/matchbox/reference/icons.md): the `.glsl.p` format

The shader list that used to be here is in the root [CLAUDE.md](CLAUDE.md).

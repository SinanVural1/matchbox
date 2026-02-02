# Chat Conversation

Note: _This is purely the output of the chat conversation and does not contain any raw data, codebase snippets, etc. used to generate the output._

### User Input

New shader: lightning.
There should be two 2D positioners that are the actual points for the source and target. And an optional 2D positioner that can be used to add curvature to the lightning bolt
Here are some initial parameters we need
Bolt width and variation
End pointiness
Wiggle speed, amplitude
Branch number, angle, length

*Listed directory [matchbox](file:///Users/sinan/Downloads/matchbox) *

*Read resource from /Users/sinan/Downloads/matchbox/tria_ag_01.glsl *

*Viewed [tria_ag_01.glsl](file:///Users/sinan/Downloads/matchbox/tria_ag_01.glsl) *

*Viewed [tria_ag_01.xml](file:///Users/sinan/Downloads/matchbox/tria_ag_01.xml) *

*Edited relevant file*

*Viewed [directional_blur.xml](file:///Users/sinan/Downloads/matchbox/directional_blur.xml) *

*Edited relevant file*

### User Input



*Edited relevant file*

*Edited relevant file*

*Edited relevant file*

*Edited relevant file*

*Edited relevant file*

### User Input

Not bad. We need the icons that we implemented in the voronoi_scatter to control the start and end points. Let's add the curve control point by default and its position should be the middle point of start/end points at the beginning. Take a look at the curves.xml and we can use the monochrome curve editor to adjust the ”pointiness” behaviour instead of just a scalar value.
There are some other stuff but let's do these first


*Viewed [Voronoi_Scatter.glsl](file:///Users/sinan/Downloads/matchbox/Voronoi_Scatter.glsl) *

*Viewed [Voronoi_Scatter.xml](file:///Users/sinan/Downloads/matchbox/Voronoi_Scatter.xml) *

*Listed directory [matchbox](file:///Users/sinan/Downloads/matchbox) *

*Edited relevant file*

### User Input



### User Input



### User Input

So, you got stuck. Let's get this step by step.
First, look at voronoi_scatter to use icons for start, end and curve controllers. We can remove the UseCurve button.

*Edited relevant file*

*Edited relevant file*

### User Input

Better. But we need to change how you add the noise. I think it is added as a 2D image postprocess after the curves are drawn. We need to use an algorithm that actually draws noisy lines. This will prevent the resulting image from breaking and creating branches that are not connected to the main body if there is too much noise. So the curve and branches should be continuously connected.

*Viewed [Curves.xml](file:///Users/sinan/Downloads/matchbox/Curves.xml) *

*Viewed [Curves.glsl](file:///Users/sinan/Downloads/matchbox/Curves.glsl) *

*Edited relevant file*

*Edited relevant file*

*Edited relevant file*

*Edited relevant file*

*Edited relevant file*

### User Input

The control point button and parameters are not visible. Probably don't have enough space for 6 rows in the UI. Let's remove it for the time being.
Also the curve widget isn't visible. Read the curves.xml again, it's got information in the comments on how to implement it

*Edited relevant file*

*Edited relevant file*
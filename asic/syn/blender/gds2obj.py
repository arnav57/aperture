# Export the sky130 metal stack of a GDS region as a Wavefront OBJ (one object per layer),
# for import into Cinema 4D / Blender. Run with KLayout in batch mode:
#
#   klayout -zz -r gds2obj.py -rd gds=build/iris_core.gds -rd out=build/stack.obj \
#           -rd box=100,100,160,140 -rd zscale=4
#
# Parameters (-rd name=value):
#   gds     input GDS (required)
#   out     output OBJ (default stack.obj)
#   box     x1,y1,x2,y2 region in um, in the top cell's coordinates (default: whole layout - can be HUGE)
#   zscale  vertical exaggeration (default 4)
#   layers  comma list of layers to export (default li,mcon,met1,via1,met2,via2,met3,via3,met4,via4,met5)
# Units in the OBJ are microns. Scale the import (e.g. x1000 in C4D) if the objects look tiny.
import pya

try: out
except NameError: out = "stack.obj"
try: zscale = float(zscale)
except NameError: zscale = 4.0
try: box
except NameError: box = None
try: layers
except NameError: layers = "li,mcon,met1,via1,met2,via2,met3,via3,met4,via4,met5"

# name: (gds layer, datatype, height in um); stacked bottom-up in this order, like the 2.5D script
STACK = {
    "li":   (67, 20, 0.200), "mcon": (67, 44, 0.350),
    "met1": (68, 20, 0.300), "via1": (68, 44, 0.350),
    "met2": (69, 20, 0.300), "via2": (69, 44, 0.350),
    "met3": (70, 20, 0.300), "via3": (70, 44, 0.350),
    "met4": (71, 20, 0.500), "via4": (71, 44, 0.400),
    "met5": (72, 20, 0.500),
}
ORDER = ["li", "mcon", "met1", "via1", "met2", "via2", "met3", "via3", "met4", "via4", "met5"]
want = set(layers.split(","))

ly = pya.Layout()
ly.read(gds)
top = ly.top_cell()
dbu = ly.dbu

if box:
    x1, y1, x2, y2 = [float(v) for v in box.split(",")]
    clip = pya.Box(int(x1/dbu), int(y1/dbu), int(x2/dbu), int(y2/dbu))
    ox, oy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
else:
    clip = top.bbox()
    ox, oy = clip.center().x * dbu, clip.center().y * dbu
# geometry is recentred on the origin so it lands in front of the Blender/C4D camera
print("[INFO] top cell", top.name, "bbox um:", top.dbbox(), "recentred by", ox, oy)

verts = []   # flat list of (x,y,z)
faces = {}   # layer -> list of vertex index tuples
z = 0.0
for name in ORDER:
    ln, dt, h = STACK[name]
    z0, z1 = z, z + h * zscale
    z = z1                      # the stack always advances so z positions stay physical
    if name not in want:
        continue
    li = ly.find_layer(ln, dt)
    if li is None:
        print(f"[WARN] layer {name} ({ln}/{dt}) not in GDS")
        continue
    region = pya.Region(top.begin_shapes_rec_touching(li, clip)).merged()
    region &= pya.Region(clip)
    fl = faces.setdefault(name, [])
    for poly in region.each():
        for t in poly.decompose_trapezoids(pya.Polygon.TD_simple):
            pts = [(p.x * dbu - ox, p.y * dbu - oy) for p in t.each_point()]
            n = len(pts)
            if n < 3:
                continue
            base = len(verts)
            for (x, y) in pts: verts.append((x, y, z0))
            for (x, y) in pts: verts.append((x, y, z1))
            bot = tuple(base + i + 1 for i in reversed(range(n)))
            topf = tuple(base + n + i + 1 for i in range(n))
            fl.append(bot); fl.append(topf)
            for i in range(n):
                j = (i + 1) % n
                fl.append((base + i + 1, base + j + 1, base + n + j + 1, base + n + i + 1))

with open(out, "w") as f:
    f.write(f"# gds2obj: {gds}, box={box}, zscale={zscale}, units=um\n")
    for (x, y, zz) in verts:
        f.write(f"v {x:.4f} {zz:.4f} {y:.4f}\n")   # y-up: GDS y -> OBJ z, height -> OBJ y
    for name in ORDER:
        if name in faces and faces[name]:
            f.write(f"o {name}\ng {name}\n")
            for face in faces[name]:
                f.write("f " + " ".join(str(i) for i in face) + "\n")

print(f"[INFO] wrote {out}: {len(verts)} vertices, " + ", ".join(f"{k}:{len(v)}" for k, v in faces.items()))

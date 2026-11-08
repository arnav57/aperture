# DEF + standard-cell GDS -> final GDSII, run via:
#   klayout -zz -rd tech=... -rd tlef=... -rd lef=... -rd def=... -rd gds=... -rd top=... -rd out=... -r stream.py
import pya
import os
tech_file, tlef, lef, in_def, std_gds, out_gds = (
    os.path.abspath(p) for p in (tech_file, tlef, lef, in_def, std_gds, out_gds)
)

tech = pya.Technology()
tech.load(tech_file)                      # noqa: F821 (globals come from -rd)
opts = tech.load_layout_options
opts.lefdef_config.lef_files = [tlef, lef]  # noqa: F821

layout = pya.Layout()
layout.read(in_def, opts)                 # noqa: F821

top_idx = layout.cell(top).cell_index()   # noqa: F821
# LEF macros come in as empty cells; clear any stub so the std-cell GDS fills them
for cell in layout.each_cell():
    if cell.cell_index() != top_idx and not cell.name.startswith("VIA_"):
        cell.clear()
layout.read(std_gds)                      # noqa: F821

# Keep only the design hierarchy
out_layout = pya.Layout()
out_layout.dbu = layout.dbu
new_top = out_layout.create_cell(top)     # noqa: F821
new_top.copy_tree(layout.cell(top))       # noqa: F821

errors = 0
for cell in out_layout.each_cell():
    if cell.is_empty():
        print(f"[ERROR] cell '{cell.name}' has no GDS content")
        errors += 1

out_layout.write(out_gds)                 # noqa: F821
print(f"[INFO] wrote {out_gds}, {errors} empty cells")  # noqa: F821
raise SystemExit(1 if errors else 0)

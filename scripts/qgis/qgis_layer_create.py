import os
import sys
from qgis.PyQt.QtCore import QVariant
from qgis.core import (
    QgsApplication,
    QgsVectorLayer,
    QgsField,
    QgsProject,
    QgsVectorFileWriter,
    edit
)

# --- Configuration (your paths) ---
project_path = "/Users/airvine/Projects/gis/ng_koot_west_2023/ng_koot_west_2023.qgs"
output_dir = "/Users/airvine/Projects/gis/ng_koot_west_2023"
layer_name = "My_Custom_Layer"
gpkg_filename = "forms.gpkg"
gpkg_filepath = os.path.join(output_dir, gpkg_filename)

# --- Helper: save aliases as default style to the GeoPackage ---
def save_default_style_to_gpkg(vlayer, alias_map):
    for fname, alias in alias_map.items():
        idx = vlayer.fields().indexOf(fname)
        if idx != -1:
            vlayer.setFieldAlias(idx, alias)

    res = vlayer.saveStyleToDatabase(
        "default",
        "with aliases",
        True,
        ""
    )
    if isinstance(res, (tuple, list)) and len(res) >= 2:
        return bool(res[0]), str(res[1])
    if isinstance(res, bool):
        return res, ""
    return True, ""

# 1) Init QGIS
qgs = QgsApplication([], False)
qgs.initQgis()
print("QGIS application initialized.")

# 2) Load project (for transform context)
project = QgsProject.instance()
if not project.read(project_path):
    print(f"Error: Failed to load project file from {project_path}")
    qgs.exitQgis(); sys.exit(1)
print(f"Project '{project.fileName()}' loaded successfully.")

# 3) Make an in-memory layer and add fields + aliases
field_defs = [
    ("name", QVariant.String, "Full Name"),
    ("age", QVariant.Int, "Age in Years"),
    ("is_active", QVariant.Bool, "Is Active?")
]
layer = QgsVectorLayer("Point?crs=EPSG:4326", layer_name, "memory")
prov = layer.dataProvider()
prov.addAttributes([QgsField(n, t) for n, t, _ in field_defs])
layer.updateFields()
for n, _t, alias in field_defs:
    idx = layer.fields().indexOf(n)
    if idx != -1:
        layer.setFieldAlias(idx, alias)

alias_map = {f.name(): f.alias() for f in layer.fields()}

# 4) Write to GeoPackage (overwrite layer if exists)
opts = QgsVectorFileWriter.SaveVectorOptions()
opts.driverName = "GPKG"
opts.layerName = layer_name
opts.actionOnExistingFile = QgsVectorFileWriter.CreateOrOverwriteLayer
err, msg = QgsVectorFileWriter.writeAsVectorFormatV2(
    layer, gpkg_filepath, project.transformContext(), opts
)

if err == QgsVectorFileWriter.NoError:
    print(f"Layer successfully saved to {gpkg_filepath}")

    # 5) Reload from GPKG, add to project, reapply aliases, save style to DB
    uri = f"{gpkg_filepath}|layername={layer_name}"
    gpkg_layer = QgsVectorLayer(uri, layer_name, "ogr")
    if gpkg_layer.isValid():
        project.addMapLayer(gpkg_layer)
        print("Layer added to project.")
        # Persist the layer in the project file so it appears next time you open QGIS
        if project.write(project_path):
            print(f"Project saved: {project_path}")
        else:
            print("Warning: failed to save project; layer won't persist in .qgs")

        ok, style_msg = save_default_style_to_gpkg(gpkg_layer, alias_map)
        if ok:
            print("Saved default style (with aliases) to GeoPackage.")
        else:
            print(f"Warning: failed to save style to GPKG: {style_msg}")

        # Explicitly write project to persist added layer
        if project.write(project_path):
            print(f"Project '{project.fileName()}' saved successfully with the new layer.")
        else:
            print("Warning: Failed to save project with new layer.")
    else:
        print("Failed to add/read the saved GeoPackage layer.")
else:
    print(f"Error saving layer: {err} - {msg}")

# 6) Shutdown
qgs.exitQgis()
print("QGIS application shut down.")

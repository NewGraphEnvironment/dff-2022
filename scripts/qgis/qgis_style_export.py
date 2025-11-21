#!/usr/bin/env python3
# qgis_style_export.py
import sys, os, argparse, re
from qgis.core import (
    QgsApplication,
    QgsProject,
    QgsProviderRegistry
)

def sanitize(name: str) -> str:
    # optional: keep gpkg table keys simple/stable
    s = re.sub(r"\s+", "_", name.strip())
    s = re.sub(r"[^A-Za-z0-9_]+", "_", s)
    return s[:63]  # gpkg table/name conventions

def main():
    ap = argparse.ArgumentParser(description="Export all layer styles from a QGIS project to a GeoPackage layer_styles table.")
    ap.add_argument("--project", "-p", required=True, help="Path to .qgs or .qgz")
    ap.add_argument("--out-gpkg", "-o", required=True, help="Path to output .gpkg (created if missing)")
    ap.add_argument("--use-names", action="store_true", help="Use raw layer names as f_table_name (instead of sanitized)")
    args = ap.parse_args()

    project_path = os.path.abspath(args.project)
    out_gpkg     = os.path.abspath(args.out_gpkg)

    # Start QGIS (no GUI)
    qgs = QgsApplication([], False)
    qgs.initQgis()

    try:
        # Load project
        prj = QgsProject.instance()
        if not prj.read(project_path):
            print(f"ERROR: Failed to read project: {project_path}", file=sys.stderr)
            sys.exit(2)

        # Ensure a connection to the target GeoPackage
        md = QgsProviderRegistry.instance().providerMetadata("ogr")  # (or "gdal" on some builds)
        conn = md.createConnection(out_gpkg, {})  # creates file if needed

        saved = 0
        for layer in prj.mapLayers().values():
            if not layer.isValid():
                continue

            table_key = layer.name() if args.use_names else sanitize(layer.name())
            
            ok = layer.saveStyleToDatabase(
                    connection=conn,
                    table=table_key,
                    name="default",
                    description="exported from project",
                    useAsDefault=True,
                    uiFileContent=""
              )

            # # Prefer V2 API if available; otherwise fall back
            # ok = False
            # if hasattr(layer, "saveStyleToDatabaseV2"):
              # ok = vlayer.saveStyleToDatabase(
              #       connection=conn,
              #       table=table_key,
              #       name="default",
              #       description="exported from project",
              #       useAsDefault=True,
              #       uiFileContent=""
              # )
            # else:
            #     # Older API writes to the project's associated DB; emulate using provider on gpkg:
            #     # Save QML to string then insert via provider util (kept simple here)
            #     from qgis.core import QgsReadWriteContext, QgsMapLayerStyle
            #     style = QgsMapLayerStyle()
            #     layer.exportNamedStyle(style)
            #     # Insert using provider helper:
            #     ok = layer.saveStyleToDatabase(
            #         name="default",
            #         description="exported from project",
            #         useAsDefault=True,
            #         uiFileContent=""
            #     )
                # Note: Old method may write to the layer's own datasource, not out_gpkg.

            print(f"{layer.name()} → {out_gpkg} [{table_key}] saved={ok}")
            if ok:
                saved += 1

        print(f"Done. Styles saved for {saved} layer(s).")
    finally:
        qgs.exitQgis()

if __name__ == "__main__":
    main()

from qgis.core import QgsProcessingAlgorithm, QgsProcessingParameterString, QgsProject
import os

class SaveLayerQml(QgsProcessingAlgorithm):
    LAYER_ID = "LAYER_ID"
    DIR_OUT = "DIR_OUT"

    def initAlgorithm(self, config=None):
        self.addParameter(QgsProcessingParameterString(self.LAYER_ID, "Layer ID"))
        self.addParameter(QgsProcessingParameterString(self.DIR_OUT, "Output directory"))

    def processAlgorithm(self, params, context, feedback):
        layer_id = self.parameterAsString(params, self.LAYER_ID, context)
        dir_out = self.parameterAsString(params, self.DIR_OUT, context)

        layer = QgsProject.instance().mapLayer(layer_id)
        if not layer:
            raise Exception(f"Layer not found: {layer_id}")

        out_path = os.path.join(dir_out, f"{layer_id}.qml")
        msg, ok = layer.saveNamedStyle(out_path)
        if not ok:
            raise Exception(f"Failed to save style: {msg}")

        return {"QML": out_path}

    def name(self): return "save_layer_qml"
    def displayName(self): return "Save layer style to QML"
    def group(self): return "Styles"
    def groupId(self): return "styles"
    def createInstance(self): return SaveLayerQml()

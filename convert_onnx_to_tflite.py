import tensorflow as tf
import onnx
from onnx_tf.backend import prepare

# Tải mô hình ONNX
# Đảm bảo file yolov8n.onnx nằm cùng thư mục với script này hoặc cung cấp đường dẫn đầy đủ
onnx_model = onnx.load("yolov8n.onnx")

# Chuẩn bị mô hình ONNX cho TensorFlow
tf_rep = prepare(onnx_model)

# Lưu mô hình TensorFlow SavedModel
tf_rep.export_graph("yolov8n_saved_model")

# Chuyển đổi SavedModel sang TFLite
converter = tf.lite.TFLiteConverter.from_saved_model("yolov8n_saved_model")
tflite_model = converter.convert()

# Lưu mô hình TFLite
with open("yolov8n.tflite", "wb") as f:
    f.write(tflite_model)

print("Chuyển đổi thành công sang yolov8n.tflite")

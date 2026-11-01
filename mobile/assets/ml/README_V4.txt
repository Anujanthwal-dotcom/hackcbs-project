
AGRICULTURE IMAGE CLASSIFIER V4
================================

CLASSES
-------
0  soybean_healthy
1  soybean_bacterial_blight
2  soybean_whitefly
3  cotton_healthy
4  cotton_bacterial_blight
5  cotton_pink_bollworm
6  negative

MODEL
-----
MobileNetV2
Input: 224 x 224 RGB

VALIDATION ACCURACY
-------------------
98.4060%

TEST ACCURACY
-------------
98.1013%

INFERENCE
---------
The Flutter application must NOT simply use argmax.

It must apply:

1. Image quality check
2. Model prediction
3. Confidence threshold
4. Top-1 / Top-2 margin
5. Negative class handling
6. Unknown rejection

THRESHOLDS
----------
Confidence:
0.550000

Margin:
0.050000

Blur:
1293.81396484

OUTPUT STATES
-------------
valid target:
  One of the six agriculture target classes.

negative:
  Other/non-target crop or trained negative image.

unknown:
  Model is not confident enough.

image_unclear:
  Camera/image quality is too poor.

IMPORTANT
---------
A normal softmax classifier always selects one class.
Therefore unknown detection is implemented using rejection
logic rather than adding "unknown" as an ordinary softmax class.

FILES
-----
plant_pest_classifier_final_v4.keras
plant_pest_classifier_final_v4.tflite
class_mapping_v4.json
inference_config_v4.json

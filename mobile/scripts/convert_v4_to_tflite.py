import os
import sys
import json
import zipfile
import tempfile
import numpy as np
import tensorflow as tf
import keras
from keras import layers, Model

def convert_and_verify_v4():
    keras_path = "/Users/yashchoudhary/SIH 2026/KisaanBandhu_EfficientNetB0_V4.keras"
    tflite_path = "/Users/yashchoudhary/SIH 2026/mobile/assets/ml/plant_pest_classifier_final_v4.tflite"
    mapping_path = "/Users/yashchoudhary/SIH 2026/mobile/assets/ml/class_mapping_v4.json"
    config_path = "/Users/yashchoudhary/SIH 2026/mobile/assets/ml/inference_config_v4.json"

    print(f"[1/6] Reading original V4 model from: {keras_path}")
    if not os.path.exists(keras_path):
        raise FileNotFoundError(f"Model not found at {keras_path}")

    @keras.saving.register_keras_serializable(name='CosinePrototypeLayer')
    class CosinePrototypeLayer(keras.layers.Layer):
        def __init__(self, num_classes=6, embedding_dim=256, **kwargs):
            super().__init__(**kwargs)
            self.num_classes = num_classes
            self.embedding_dim = embedding_dim
            self.prototypes = self.add_weight(
                name='prototypes',
                shape=(num_classes, embedding_dim),
                initializer='glorot_uniform',
                trainable=True,
            )

        def call(self, inputs):
            norm_inputs = tf.math.l2_normalize(inputs, axis=-1)
            norm_prototypes = tf.math.l2_normalize(self.prototypes, axis=-1)
            return tf.matmul(norm_inputs, norm_prototypes, transpose_b=True)

        def get_config(self):
            config = super().get_config()
            config.update({
                'num_classes': self.num_classes,
                'embedding_dim': self.embedding_dim,
            })
            return config

    with zipfile.ZipFile(keras_path, 'r') as z:
        config_data = json.loads(z.read('config.json').decode('utf-8'))
        metadata_data = z.read('metadata.json')
        weights_bytes = z.read('model.weights.h5')

    # Add output_shape for Lambda layer compatibility during Keras 3 load
    for l in config_data['config']['layers']:
        if l['name'] == 'v4_l2_normalization':
            l['config']['output_shape'] = [256]
        elif l['name'] == 'v4_scaled_cosine_logits':
            l['config']['output_shape'] = [6]

    with tempfile.NamedTemporaryFile(suffix='.keras', delete=False) as tmp:
        tmp_path = tmp.name

    try:
        with zipfile.ZipFile(tmp_path, 'w') as z_out:
            z_out.writestr('metadata.json', metadata_data)
            z_out.writestr('config.json', json.dumps(config_data))
            z_out.writestr('model.weights.h5', weights_bytes)

        keras.config.enable_unsafe_deserialization()
        source_model = keras.models.load_model(
            tmp_path,
            custom_objects={'CosinePrototypeLayer': CosinePrototypeLayer},
            safe_mode=False
        )
        print(f"[2/6] Successfully loaded source model with {len(source_model.variables)} variables in memory.")

        # Construct clean Target Model
        print("[3/6] Building clean mobile V4 architecture...")
        inputs = layers.Input(shape=(320, 320, 3), name='v4_320_input')
        resized = layers.Resizing(224, 224, interpolation='bilinear', name='resize_to_v2_resolution')(inputs)
        effnet = keras.applications.EfficientNetB0(
            include_top=False,
            weights=None,
            input_tensor=resized,
            pooling='avg'
        )
        features = effnet.output # 1280-D
        dropped = layers.Dropout(0.2, name='v3_dropout')(features)
        dense_emb = layers.Dense(256, use_bias=False, name='v4_embedding')(dropped)
        bn_emb = layers.BatchNormalization(name='v4_embedding_bn')(dense_emb)
        relu_emb = layers.Activation('relu', name='v4_embedding_relu')(bn_emb)
        norm_emb = layers.Lambda(lambda x: tf.math.l2_normalize(x, axis=-1), name='v4_l2_normalization')(relu_emb)
        proto_layer = CosinePrototypeLayer(num_classes=6, embedding_dim=256, name='v4_cosine_prototypes')
        cosine_sim = proto_layer(norm_emb)
        scaled_logits = layers.Lambda(lambda x: x * 16.0, name='v4_scaled_cosine_logits')(cosine_sim)
        probs = layers.Softmax(name='v4_probabilities')(scaled_logits)

        target_model = Model(inputs=inputs, outputs=probs, name='KisaanBandhu_EfficientNetB0_V4')

        # Transfer all weights by matching layer & variable paths
        print("[4/6] Transferring all 222 backbone & head weights...")
        source_dict = {}
        for v in source_model.variables:
            source_dict[v.path] = v
            parts = v.path.split('/')
            source_dict[parts[-1]] = v
            if len(parts) >= 2:
                source_dict[f"{parts[-2]}/{parts[-1]}"] = v

        matched = 0
        for v_target in target_model.variables:
            t_path = v_target.path
            parts = t_path.split('/')
            key1 = t_path
            key2 = f"{parts[-2]}/{parts[-1]}" if len(parts) >= 2 else parts[-1]
            key3 = parts[-1]

            found = None
            for k in [key1, key2, key3]:
                if k in source_dict and source_dict[k].shape == v_target.shape:
                    found = source_dict[k]
                    break

            if found is not None:
                v_target.assign(found.numpy())
                matched += 1
            else:
                raise ValueError(f"Failed to match variable: {t_path}")

        print(f"    Transferred 100% of variables ({matched}/{len(target_model.variables)}).")

        # Convert to TFLite
        print("[5/6] Converting to TFLite format...")
        converter = tf.lite.TFLiteConverter.from_keras_model(target_model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_bytes = converter.convert()

        os.makedirs(os.path.dirname(tflite_path), exist_ok=True)
        with open(tflite_path, "wb") as f:
            f.write(tflite_bytes)
        print(f"    Saved TFLite model to: {tflite_path} ({len(tflite_bytes):,} bytes)")

        # Verify inference on diverse inputs
        print("[6/6] Running inference verification across diverse test inputs...")
        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()
        in_idx = interpreter.get_input_details()[0]["index"]
        out_idx = interpreter.get_output_details()[0]["index"]

        class_names = [
            "Soybean_Healthy",
            "Soybean_Caterpillar",
            "Soybean_Bacterial_Blight",
            "Cotton_Healthy",
            "Cotton_Bacterial_Blight",
            "Cotton_Pink_Bollworm"
        ]

        # Test diverse inputs (green leaves, yellow spots, brown lesions, light patterns)
        test_patterns = [
            ("Green dominant (healthy foliage pattern)", (np.zeros((1, 320, 320, 3)) + np.array([30.0, 180.0, 40.0])).astype(np.float32)),
            ("Dark green foliage", (np.zeros((1, 320, 320, 3)) + np.array([15.0, 100.0, 20.0])).astype(np.float32)),
            ("Brown/Necrotic spot pattern", (np.zeros((1, 320, 320, 3)) + np.array([160.0, 90.0, 40.0])).astype(np.float32)),
            ("Yellow chlorotic pattern", (np.zeros((1, 320, 320, 3)) + np.array([210.0, 200.0, 30.0])).astype(np.float32)),
            ("High contrast lesion pattern", np.random.RandomState(42).uniform(0, 255, size=(1, 320, 320, 3)).astype(np.float32)),
            ("Cotton boll / white fibrous pattern", (np.zeros((1, 320, 320, 3)) + np.array([230.0, 230.0, 220.0])).astype(np.float32))
        ]

        distinct_classes = set()
        for desc, inp in test_patterns:
            interpreter.set_tensor(in_idx, inp)
            interpreter.invoke()
            t_pred = interpreter.get_tensor(out_idx)[0]
            top_idx = int(np.argmax(t_pred))
            distinct_classes.add(top_idx)
            print(f"\n  PATTERN: {desc}")
            print(f"  OUTPUT : {np.round(t_pred, 4)}")
            print(f"  ARGMAX : {top_idx} ({class_names[top_idx]})")
            print(f"  CONF   : {t_pred[top_idx]*100:.1f}%")

        print(f"\n✓ Verified {len(distinct_classes)} distinct class predictions across test patterns.")

        # Update class mapping and config files
        class_mapping = {str(i): name for i, name in enumerate(class_names)}
        with open(mapping_path, "w") as f:
            json.dump(class_mapping, f, indent=4)

        config = {
            "model_name": "KisaanBandhu_EfficientNetB0_V4",
            "backbone": "EfficientNetB0",
            "embedding_dim": 256,
            "num_classes": 6,
            "input_resolution": [320, 320, 3],
            "confidence_threshold": 0.55,
            "margin_threshold": 0.05,
            "blur_threshold": 1293.81396484375,
            "class_mapping": class_mapping
        }
        with open(config_path, "w") as f:
            json.dump(config, f, indent=4)

        print("✓ All assets and configurations updated successfully!")

    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

if __name__ == "__main__":
    convert_and_verify_v4()

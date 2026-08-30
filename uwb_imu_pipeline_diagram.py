# UWB + IMU + Deep Neural Network Data Fusion Pipeline Diagram
# Designed for inclusion in Chapter 1 of Master's Thesis

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

fig, ax = plt.subplots(figsize=(12, 7))
ax.axis('off')

# Data blocks
ax.text(0.05, 0.8, 'UWB Raw Data\n(TDOA Measurements)', ha='center', va='center', fontsize=11, bbox=dict(boxstyle='round,pad=0.3', facecolor='#d0e1ff'))
ax.text(0.05, 0.6, 'IMU Raw Data\n(Accelerometer, Gyroscope)', ha='center', va='center', fontsize=11, bbox=dict(boxstyle='round,pad=0.3', facecolor='#d0e1ff'))

# Preprocessing
ax.text(0.3, 0.7, 'Data Extraction & Synchronization\n(data_extractor.m)', ha='center', va='center', fontsize=11, bbox=dict(boxstyle='round,pad=0.3', facecolor='#f5e3b3'))

# Dataset generation
ax.text(0.5, 0.7, 'Dataset Generator\n(dataset_generator_runner.m)', ha='center', va='center', fontsize=11, bbox=dict(boxstyle='round,pad=0.3', facecolor='#f3d6b2'))

# Model training
ax.text(0.7, 0.85, 'FNN Training\n(train_tdoa_net.m)', ha='center', va='center', fontsize=10, bbox=dict(boxstyle='round,pad=0.3', facecolor='#d4f5d0'))
ax.text(0.7, 0.7, 'CNN Training\n(train_tdoa_cnn_net.m)', ha='center', va='center', fontsize=10, bbox=dict(boxstyle='round,pad=0.3', facecolor='#d4f5d0'))
ax.text(0.7, 0.55, 'LSTM Training\n(train_tdoa_lstm_net.m)', ha='center', va='center', fontsize=10, bbox=dict(boxstyle='round,pad=0.3', facecolor='#d4f5d0'))

# Baseline filter
ax.text(0.5, 0.5, 'Baseline Filter\n(Extended Kalman Filter - fusion_eskf.m)', ha='center', va='center', fontsize=10, bbox=dict(boxstyle='round,pad=0.3', facecolor='#c8e4fa'))

# Inference
ax.text(0.9, 0.7, 'Inference & Comparison\n(inference.m / inference_lstm.m)\nRMSE Evaluation', ha='center', va='center', fontsize=10, bbox=dict(boxstyle='round,pad=0.3', facecolor='#f2c0c0'))

# Arrows
arrow_args = dict(arrowstyle='->', lw=1.5, color='gray')
ax.annotate('', xy=(0.22, 0.7), xytext=(0.1, 0.8), arrowprops=arrow_args)
ax.annotate('', xy=(0.22, 0.7), xytext=(0.1, 0.6), arrowprops=arrow_args)
ax.annotate('', xy=(0.4, 0.7), xytext=(0.33, 0.7), arrowprops=arrow_args)
ax.annotate('', xy=(0.6, 0.85), xytext=(0.55, 0.7), arrowprops=arrow_args)
ax.annotate('', xy=(0.6, 0.7), xytext=(0.55, 0.7), arrowprops=arrow_args)
ax.annotate('', xy=(0.6, 0.55), xytext=(0.55, 0.7), arrowprops=arrow_args)
ax.annotate('', xy=(0.82, 0.7), xytext=(0.77, 0.85), arrowprops=arrow_args)
ax.annotate('', xy=(0.82, 0.7), xytext=(0.77, 0.7), arrowprops=arrow_args)
ax.annotate('', xy=(0.82, 0.7), xytext=(0.77, 0.55), arrowprops=arrow_args)

plt.show()
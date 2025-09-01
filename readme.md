# Jetson Utilities Installer

A collection of automated installation scripts for essential AI/ML libraries on NVIDIA Jetson devices. These scripts simplify the complex process of installing PyTorch, OpenCV, and other ML frameworks with proper CUDA acceleration support.

## 🎯 Use Case

This repository addresses the common challenges faced when setting up machine learning environments on NVIDIA Jetson devices:

- **Complex Dependencies**: Managing CUDA versions, JetPack compatibility, and library interdependencies
- **Time-Consuming Builds**: Avoiding lengthy compilation processes with pre-built solutions where possible
- **Version Conflicts**: Ensuring compatibility between different ML frameworks and system libraries
- **CUDA Acceleration**: Properly configuring libraries to leverage Jetson's GPU capabilities

Perfect for developers, researchers, and hobbyists who want to quickly set up a robust ML environment on their Jetson devices without dealing with compilation headaches.

## 🛠 Available Scripts

| Script | Purpose | JetPack Support | Installation Method | Estimated Time |
|--------|---------|----------------|-------------------|----------------|
| `install_pytorch.sh` | PyTorch with CUDA support | 5.1.1, 5.1.2, 6.0, 6.1, 6.2 | Pre-built wheels | 5-10 minutes |
| `build_opencv.sh` | OpenCV with CUDA/cuDNN/GStreamer | All versions | Source compilation | 2-4 hours |
| *Future scripts* | *Additional ML libraries* | *TBD* | *TBD* | *TBD* |

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/jetson-utilities.git
cd jetson-utilities

# Make scripts executable
chmod +x *.sh

# Install PyTorch (interactive)
./install_pytorch.sh

# Build OpenCV with CUDA (long process)
./build_opencv.sh
```

---

## 📋 Script Documentation

### PyTorch Installer (`install_pytorch.sh`)

Interactive installer for PyTorch with CUDA support on Jetson devices.

#### Features
- **Interactive JetPack Detection**: Automatically detects or asks for your JetPack version
- **Smart Wheel Selection**: Provides tested default wheel URLs with override options
- **cuSPARSELt Integration**: Automatically installs cuSPARSELt for JP ≥ 6.0 compatibility
- **CUDA Validation**: Verifies PyTorch installation and CUDA availability
- **Dependency Management**: Handles torchvision and torchaudio compatibility

#### Usage
```bash
./install_pytorch.sh
```

#### Interactive Prompts
1. **JetPack Version**: Enter your JetPack code (`511`, `512`, `60`, `61`, `62`)
2. **Wheel URL**: Accept the default or provide a custom PyTorch wheel URL
3. **Installation Confirmation**: Review settings before proceeding

#### Supported Configurations
- **JetPack 5.1.1/5.1.2**: PyTorch wheels without cuSPARSELt requirement
- **JetPack 6.0+**: Latest PyTorch wheels with automatic cuSPARSELt installation

#### Testing PyTorch Installation
After installation, verify PyTorch is working correctly:

```python
# Test basic PyTorch functionality
python3 -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU count: {torch.cuda.device_count()}')
    print(f'GPU name: {torch.cuda.get_device_name(0)}')

    # Test tensor operations on GPU
    x = torch.randn(3, 3).cuda()
    y = torch.randn(3, 3).cuda()
    z = torch.mm(x, y)
    print('GPU tensor operations: SUCCESS')
"
```

#### Troubleshooting
- **cuSPARSELt Issues**: Ensure you're using the script on JP 6.0+ for automatic cuSPARSELt installation
- **Wheel Compatibility**: Verify your JetPack version matches the selected wheel
- **Memory Issues**: Close other applications during installation to free up RAM

---

### OpenCV Builder (`build_opencv.sh`)

Comprehensive OpenCV compilation script with CUDA, cuDNN, and GStreamer support.

#### Features
- **Full CUDA Integration**: Builds OpenCV with CUDA and cuDNN acceleration
- **GStreamer Support**: Enables hardware-accelerated video processing
- **Python Bindings**: Includes Python 3 bindings for cv2
- **System-wide Installation**: Installs OpenCV globally for all users
- **Optimized Build**: Configured for Jetson hardware optimization

#### Usage
```bash
# Start the build process (this will take 2-4 hours)
./build_opencv.sh

# Monitor progress
tail -f /tmp/opencv_build.log  # if logging is implemented
```

#### Build Configuration
The script configures OpenCV with:
- CUDA acceleration for image processing
- cuDNN support for deep learning inference
- GStreamer integration for video I/O
- Python 3 bindings
- Optimized compiler flags for ARM64

#### Testing OpenCV Installation
Verify your OpenCV installation after the build completes:

```python
# Test basic OpenCV functionality
python3 -c "
import cv2
import numpy as np

print(f'OpenCV version: {cv2.__version__}')

# Test CUDA support
print(f'CUDA devices: {cv2.cuda.getCudaEnabledDeviceCount()}')

# Test basic image operations
img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
blur = cv2.GaussianBlur(gray, (15, 15), 0)
print('Basic image operations: SUCCESS')

# Test CUDA image operations (if CUDA is available)
if cv2.cuda.getCudaEnabledDeviceCount() > 0:
    gpu_img = cv2.cuda_GpuMat()
    gpu_img.upload(img)
    gpu_gray = cv2.cuda.cvtColor(gpu_img, cv2.COLOR_BGR2GRAY)
    result = gpu_gray.download()
    print('GPU image operations: SUCCESS')
"
```

#### Performance Testing
Test OpenCV performance with CUDA acceleration:

```python
# Performance comparison script
python3 -c "
import cv2
import numpy as np
import time

# Create test image
img = np.random.randint(0, 255, (1920, 1080, 3), dtype=np.uint8)

# CPU processing
start_time = time.time()
for _ in range(100):
    gray_cpu = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur_cpu = cv2.GaussianBlur(gray_cpu, (15, 15), 0)
cpu_time = time.time() - start_time
print(f'CPU processing time: {cpu_time:.3f} seconds')

# GPU processing (if available)
if cv2.cuda.getCudaEnabledDeviceCount() > 0:
    gpu_img = cv2.cuda_GpuMat()
    gpu_img.upload(img)

    start_time = time.time()
    for _ in range(100):
        gpu_gray = cv2.cuda.cvtColor(gpu_img, cv2.COLOR_BGR2GRAY)
        gpu_blur = cv2.cuda.bilateralFilter(gpu_gray, -1, 50, 50)
    cv2.cuda.deviceSynchronize()
    gpu_time = time.time() - start_time
    print(f'GPU processing time: {gpu_time:.3f} seconds')
    print(f'Speedup: {cpu_time/gpu_time:.2f}x')
"
```

---

## 🔧 System Requirements

### Hardware
- NVIDIA Jetson Nano, Xavier NX, AGX Xavier, or Orin series
- At least 4GB RAM (8GB+ recommended for OpenCV compilation)
- 16GB+ free storage space

### Software
- Ubuntu 18.04/20.04/22.04 (depending on JetPack version)
- JetPack 5.1.1, 5.1.2, 6.0, 6.1, or 6.2
- CUDA toolkit (installed with JetPack)
- Python 3.6+ with pip

### Pre-installation Setup
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential development tools
sudo apt install -y build-essential cmake git wget curl

# Verify CUDA installation
nvcc --version
```

## 📊 Performance Notes

- **PyTorch Installation**: Typically completes in 5-10 minutes
- **OpenCV Compilation**: Expect 2-4 hours depending on Jetson model and available RAM
- **Memory Usage**: OpenCV compilation may use significant RAM; close unnecessary applications
- **Storage**: Each installation requires several GB of temporary space

## 🤝 Contributing

Contributions are welcome! Please consider adding:
- Support for additional JetPack versions
- New ML library installation scripts
- Performance optimizations
- Bug fixes and improvements

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Important Notes

- **Backup Your System**: Always create a system backup before running installation scripts
- **JetPack Compatibility**: Ensure your JetPack version is supported before proceeding
- **Internet Connection**: Stable internet connection required for downloading packages
- **Patience Required**: OpenCV compilation is time-consuming but worth the wait for optimal performance

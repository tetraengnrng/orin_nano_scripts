#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]} failed on line ${LINENO}"; exit 1' ERR

# Tunables
PREFIX=/usr/local
OPENCV_VER="${1:-4.12.0}"     # override with: ./build_opencv.sh 4.10.0
JOBS=$(nproc)
CUDA_ARCH_BIN="${CUDA_ARCH_BIN:-8.7}"  # Orin=8.7; Xavier=7.2; Nano=5.3

# For low-RAM systems you can cap jobs:
if [[ $JOBS -le 5 ]]; then JOBS=1; fi

say(){ echo -e "\033[1;36m[build-opencv]\033[0m $*"; }

install_deps() {
  say "Installing dependencies…"
  sudo apt-get update
  sudo apt-get dist-upgrade -y --autoremove
  sudo apt-get install -y \
    build-essential cmake git gfortran pkg-config \
    libgtk-3-dev libcanberra-gtk3-module \
    libjpeg-dev libpng-dev libtiff-dev \
    libavcodec-dev libavformat-dev libswscale-dev ffmpeg \
    libv4l-dev v4l-utils \
    libxvidcore-dev libx264-dev \
    libtbb-dev libeigen3-dev libdc1394-dev \
    gstreamer1.0-tools gstreamer1.0-plugins-{base,good,bad} \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    python3-dev python3-pip python3-numpy
}

setup_tree() {
  say "Preparing /tmp/build_opencv…"
  rm -rf /tmp/build_opencv
  mkdir -p /tmp/build_opencv && cd /tmp/build_opencv
}

fetch_sources() {
  say "Cloning OpenCV ${OPENCV_VER}…"
  git clone --depth 1 --branch "${OPENCV_VER}" https://github.com/opencv/opencv.git
  git clone --depth 1 --branch "${OPENCV_VER}" https://github.com/opencv/opencv_contrib.git
}

configure_build() {
  say "Configuring CMake…"
  PY_EXEC=$(python3 -c "import sys; print(sys.executable)")
  PY_SITE=$(python3 - <<'PY'
import sysconfig; print(sysconfig.get_paths()['purelib'])
PY
)
  mkdir -p opencv/build && cd opencv/build
  cmake -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX="${PREFIX}" \
        -D OPENCV_EXTRA_MODULES_PATH=/tmp/build_opencv/opencv_contrib/modules \
        -D OPENCV_ENABLE_NONFREE=ON \
        -D OPENCV_DNN_CUDA=ON \
        -D WITH_CUDA=ON \
        -D WITH_CUDNN=ON \
        -D WITH_CUBLAS=ON \
        -D ENABLE_FAST_MATH=1 \
        -D CUDA_FAST_MATH=1 \
        -D CUDA_ARCH_BIN="${CUDA_ARCH_BIN}" \
        -D WITH_GSTREAMER=ON \
        -D WITH_LIBV4L=ON \
        -D WITH_OPENGL=ON \
        -D BUILD_opencv_python2=OFF \
        -D BUILD_opencv_python3=ON \
        -D PYTHON3_EXECUTABLE="${PY_EXEC}" \
        -D PYTHON3_PACKAGES_PATH="${PY_SITE}" \
        -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_EXAMPLES=OFF \
        .. 2>&1 | tee configure.log
}

build_and_install() {
  say "Building with ${JOBS} jobs…"
  make -j"${JOBS}" 2>&1 | tee build.log
  say "Installing to ${PREFIX}…"
  if [[ -w "${PREFIX}" ]]; then
    make install 2>&1 | tee install.log
  else
    sudo make install 2>&1 | tee install.log
  fi
  sudo ldconfig
}

cleanup_prompt() {
  while true; do
    read -rp "Remove /tmp/build_opencv temporary files? [Y/N] " yn
    case "$yn" in
      [Yy]*) rm -rf /tmp/build_opencv; break;;
      [Nn]*) break;;
      *) echo "Please answer Y or N.";;
    esac
  done
}

main() {
  install_deps
  setup_tree
  fetch_sources
  configure_build
  build_and_install
  cleanup_prompt
  echo "Done. Verify with: python3 -c 'import cv2; bi=cv2.getBuildInformation(); print("OpenCV", cv2.__version__, "| built_with_cuda=", ("YES" if "NVIDIA CUDA: YES" in bi else "NO"), "| cudnn=", ("YES" if "cuDNN: YES" in bi else "NO"), "| cuda_module=", ("YES" if hasattr(cv2,"cuda") else "NO"), "| cuda_devices=", (cv2.cuda.getCudaEnabledDeviceCount() if hasattr(cv2,"cuda") else 0))'"
}
main "$@"

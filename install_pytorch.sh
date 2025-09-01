#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]} failed at line ${LINENO}"; exit 1' ERR

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "ERROR: This script targets NVIDIA Jetson (aarch64)."
  exit 1
fi

echo "=== PyTorch Installer for Jetson ==="
read -rp "Enter JetPack code (examples: 511, 512, 60, 61, 62): " JP
JP="${JP//[[:space:]]/}"

# Detect python tag (cpXX) automatically
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info[0]}{sys.version_info[1]}")')
CPTAG="cp${PYVER}-cp${PYVER}"
echo "Detected Python tag: ${CPTAG}"

# Map JP -> default wheel URL (user can override later)
WHEEL_URL=""
case "${JP}" in
  511)
    WHEEL_URL="https://developer.download.nvidia.com/compute/redist/jp/v511/pytorch/torch-2.0.0+nv23.05-cp38-cp38-linux_aarch64.whl"  # cp38
    ;;
  512)
    WHEEL_URL="https://developer.download.nvidia.com/compute/redist/jp/v512/pytorch/torch-2.1.0a0+41361538.nv23.06-cp38-cp38-linux_aarch64.whl" # cp38
    ;;
  60)
    # Several 2.4.0 wheels exist; default to the newer one
    WHEEL_URL="https://developer.download.nvidia.com/compute/redist/jp/v60/pytorch/torch-2.4.0a0+3bcc3cddb5.nv24.07.16234504-cp310-cp310-linux_aarch64.whl"
    ;;
  61)
    # Known working (your link)
    WHEEL_URL="https://developer.download.nvidia.com/compute/redist/jp/v61/pytorch/torch-2.5.0a0+872d972e41.nv24.08.17622132-cp310-cp310-linux_aarch64.whl"
    ;;
  62)
    echo "NOTICE: NVIDIA hasn't published a v62 wheel directory yet."
    echo "Provide a direct wheel URL for JP62 (or use a Jetson container)."
    ;;
  *)
    echo "ERROR: Unknown JP code '${JP}'. Valid examples: 511, 512, 60, 61, 62"
    exit 1
    ;;
esac

read -rp "Wheel URL [default: ${WHEEL_URL:-<none>}]: " USER_URL || true
USER_URL="${USER_URL//[[:space:]]/}"
TORCH_URL="${USER_URL:-$WHEEL_URL}"

if [[ -z "${TORCH_URL}" ]]; then
  echo "ERROR: No wheel URL provided."
  echo "Tip: Browse https://developer.download.nvidia.com/compute/redist/jp/ then pick your v<JP>/pytorch/ wheel."
  exit 1
fi

echo "Selected: ${TORCH_URL}"
echo "Updating apt deps…"
sudo apt-get update -y
sudo apt-get install -y python3-pip libopenblas-dev curl

# Install cuSPARSELt first for JP >= 60 (PyTorch >= 24.06 needs it)
if [[ "${JP}" =~ ^6 ]]; then
  echo "Installing cuSPARSELt (required for JP ${JP})…"
  # Use bundled installer next to this script if present, else fetch inline
  if [[ -f "./install_cusparselt.sh" ]]; then
    CUDA_VERSION="${CUDA_VERSION:-}" bash ./install_cusparselt.sh
  else
    TMP="$(mktemp -d)"
    cat > "${TMP}/install_cusparselt.sh" <<'CUS'
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "cuSPARSELt installer error on line ${LINENO}"; exit 1' ERR
: "${DEST_CUDA:=/usr/local/cuda}"
: "${CUSPARSELT_VER:=0.7.1.0}"
if [[ -z "${CUDA_VERSION:-}" ]]; then
  if [[ -f "${DEST_CUDA}/version.txt" ]]; then
    CUDA_VERSION="$(grep -oE '[0-9]+\.[0-9]+' "${DEST_CUDA}/version.txt" | head -n1)"
  elif command -v nvcc >/dev/null 2>&1; then
    CUDA_VERSION="$(nvcc --version | sed -n 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)"
  else
    echo "ERROR: Set CUDA_VERSION=MAJOR.MINOR"; exit 1
  fi
fi
ARCH_DIR="linux-aarch64"; BASE_URL="https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/${ARCH_DIR}"
PKG="libcusparse_lt-${ARCH_DIR}-${CUSPARSELT_VER}-archive"; TAR="${PKG}.tar.xz"
TMPD="$(mktemp -d)"; cd "$TMPD"
if ! curl -fS --retry 3 -O "${BASE_URL}/${TAR}"; then
  FALLBACK_BASE="https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/linux-sbsa"
  PKG="libcusparse_lt-linux-sbsa-0.5.2.1-archive"; TAR="${PKG}.tar.xz"
  curl -fS --retry 3 -O "${FALLBACK_BASE}/${TAR}"
fi
tar xf "${TAR}"
sudo mkdir -p "${DEST_CUDA}/include" "${DEST_CUDA}/lib64"
sudo cp -a "${PKG}/include/." "${DEST_CUDA}/include/"
sudo cp -a "${PKG}/lib/."     "${DEST_CUDA}/lib64/"
sudo ldconfig
ls "${DEST_CUDA}/lib64"/libcusparseLt.so* >/dev/null 2>&1 || { echo "ERROR: libcusparseLt missing"; exit 1; }
CUS
    bash "${TMP}/install_cusparselt.sh"
  fi
fi

echo "Upgrading pip and (if needed) numpy pin…"
python3 -m pip install --upgrade pip
# NVIDIA docs often require numpy==1.26.1 for these wheels (esp. JP6.0/6.1)
if [[ "${JP}" == "60" || "${JP}" == "61" ]]; then
  python3 -m pip install "numpy"
fi

echo "Installing torch wheel…"
python3 -m pip install --no-cache-dir "${TORCH_URL}"

echo "Verifying PyTorch + CUDA…"
python3 - <<'PY'
import sys
try:
    import torch
    print("torch:", torch.__version__)
    print("built with CUDA:", torch.version.cuda)
    print("CUDA available:", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("GPU:", torch.cuda.get_device_name(0))
except Exception as e:
    print("ERROR importing torch:", e)
    sys.exit(1)
PY

echo "SUCCESS: PyTorch installed."

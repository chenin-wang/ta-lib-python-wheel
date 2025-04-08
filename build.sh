#!/bin/bash
set -eo pipefail # Exit on error, catch pipe failures

# --- Configuration ---
# Expected directory name inside the C source zip (adjust if needed)
# Usually 'ta-lib-<version>' but GitHub might use 'ta-lib-<git-sha>' or just 'ta-lib' on some tags/branches
# Let's assume it's predictable based on the tag for simplicity here.
EXPECTED_C_SRC_DIR="ta-lib-$TALIB_C_VER"

# --- Check required environment variables ---
if [ -z "$TALIB_C_VER" ]; then
    echo "ERROR: TALIB_C_VER environment variable not set" >&2 # Redirect errors to stderr
    exit 1
fi
if [ -z "$TALIB_PY_VER" ]; then
    echo "ERROR: TALIB_PY_VER environment variable not set" >&2
    exit 1
fi

echo "Building with TA-Lib C version: $TALIB_C_VER"
echo "Building for TA-Lib Python version: $TALIB_PY_VER"
echo "Working directory: $(pwd)"

# --- Download C Source ---
C_ZIP_FILE="talib-c-v${TALIB_C_VER}.zip"
echo "Downloading TA-Lib C source code (v$TALIB_C_VER)..."
curl -SL -o "$C_ZIP_FILE" "https://github.com/TA-Lib/ta-lib/archive/refs/tags/v${TALIB_C_VER}.zip" # Use -S for silent, -L for redirects

# --- Extract C Source ---
echo "Extracting TA-Lib C source ($C_ZIP_FILE)..."
unzip -oq "$C_ZIP_FILE" # Use -o (overwrite), -q (quiet)
# Verify the expected directory exists
if [ ! -d "$EXPECTED_C_SRC_DIR" ]; then
    echo "ERROR: Extracted C source directory '$EXPECTED_C_SRC_DIR' not found!" >&2
    echo "Contents of current directory:"
    ls -la
    # Attempt to find the actual directory name (common pattern)
    ACTUAL_C_SRC_DIR=$(find . -maxdepth 1 -type d -name 'ta-lib*' ! -print -quit)
    if [ -n "$ACTUAL_C_SRC_DIR" ] && [ -d "$ACTUAL_C_SRC_DIR" ]; then
         echo "Found potential directory: $ACTUAL_C_SRC_DIR. Please adjust EXPECTED_C_SRC_DIR in the script." >&2
    fi
    exit 1
fi
echo "Found C source directory: $EXPECTED_C_SRC_DIR"

# --- Build TA-Lib C library (Locally) ---
echo "Building TA-Lib C library inside $EXPECTED_C_SRC_DIR..."
# Define a local installation prefix within the workspace
INSTALL_PREFIX="$(pwd)/talib_install"
mkdir -p "$INSTALL_PREFIX/lib" "$INSTALL_PREFIX/include" # Create directories

# Store the absolute path *before* changing directory
# These will point to the *installed* locations after 'make install'
C_BUILD_DIR="$INSTALL_PREFIX/lib"
C_INCLUDE_DIR="$INSTALL_PREFIX/include"

pushd "$EXPECTED_C_SRC_DIR" # Change into C source directory
echo "Current directory: $(pwd)..."
echo "Listing contents before build steps:"
ls -la

# *** ADDED STEP: Generate configure script ***
# Check if configure exists, if not, try to generate it
if [ ! -f configure ]; then
    echo "'configure' script not found. Trying to generate it using autoreconf..."
    # Check if configure.ac exists as a prerequisite for autoreconf
    if [ -f configure.ac ]; then
        autoreconf --install --force --verbose || { echo "autoreconf failed"; popd; exit 1; }
        echo "autoreconf completed. Contents after autoreconf:"
        ls -la
    else
        echo "ERROR: Neither 'configure' nor 'configure.ac' found in $(pwd)." >&2
        popd # Go back before exiting
        exit 1
    fi
fi

# Ensure configure is executable (autoreconf usually does this, but belt-and-suspenders)
chmod +x configure

# *** MODIFIED STEP: Configure for local install and PIC ***
echo "Running configure with prefix=$INSTALL_PREFIX..."
# Add CFLAGS for position-independent code, crucial for Python extensions linking to the library
export CFLAGS="-fPIC"
# Configure to install into our local directory, not system-wide
./configure --prefix="$INSTALL_PREFIX" || { echo "configure failed"; popd; exit 1; }

# Build the library
echo "Running make..."
make || { echo "make failed"; popd; exit 1; }

# Install into the local prefix specified above (no sudo needed)
echo "Running make install..."
make install || { echo "make install failed"; popd; exit 1; }

popd # Return to the original directory

# --- Export Environment Variables for Python Build ---
export TA_INCLUDE_PATH="${C_INCLUDE_DIR}"
export TA_LIBRARY_PATH="${C_BUILD_DIR}"
echo "Exported TA_INCLUDE_PATH=${TA_INCLUDE_PATH}"
echo "Exported TA_LIBRARY_PATH=${TA_LIBRARY_PATH}"

# --- Download Python Source ---
PY_ZIP_FILE="talib-py-v${TALIB_PY_VER}.tar.gz" # Use consistent naming
echo "Downloading TA-Lib Python source code (v$TALIB_PY_VER)..."
curl -SL -o "$PY_ZIP_FILE" "https://github.com/TA-Lib/ta-lib-python/archive/refs/tags/TA_Lib-$TALIB_PY_VER.tar.gz"

# --- Extract Python Source ---
echo "Extracting TA-Lib Python source ($PY_ZIP_FILE)..."
tar -xf "$PY_ZIP_FILE" --strip-components=1
echo "Contents after Python source extraction:"
ls -la

# --- Cleanup Download ---
echo "Cleaning up downloaded zip file..."
rm -f "$PY_ZIP_FILE"

# --- Copy Build Artifacts to Target Directories ---
echo "Copying TA-Lib artifacts to target directories..."

SOURCE_BUILD_DIR="$INSTALL_PREFIX/lib"
SOURCE_INCLUDE_SUBDIR="$INSTALL_PREFIX/include" # Headers were prepared here earlier

# **Copy Library Files**
echo "Copying library files from ${SOURCE_BUILD_DIR} to ${pwd}..."
cp -r "${SOURCE_BUILD_DIR}" .
ls -lR "./lib" # List parent include dir for debugging
# **Copy Header Files**
echo "Copying header files from ${SOURCE_INCLUDE_SUBDIR} to ${pwd}..."
cp -r "${SOURCE_INCLUDE_SUBDIR}" .
ls -lR "./include" # List parent include dir for debugging

echo "--------------------------------------------------"
echo "TA-Lib artifacts copied successfully."
echo "TA-Lib C build and Python source extraction complete."
echo "--------------------------------------------------"
exit 0
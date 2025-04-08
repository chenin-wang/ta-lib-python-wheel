:: build.cmd
@echo on
setlocal enabledelayedexpansion

:: 设置 TA-Lib 相关变量
if "%TALIB_C_VER%"=="" (
    echo ERROR: TALIB_C_VER environment variable not set
    exit /B 1
)
if "%TALIB_PY_VER%"=="" (
    echo ERROR: TALIB_PY_VER environment variable not set
    exit /B 1
)

echo Building with TA-Lib C version: %TALIB_C_VER%
echo Building for TA-Lib Python version: %TALIB_PY_VER%
set CMAKE_GENERATOR=NMake Makefiles
set CMAKE_BUILD_TYPE=Release
set CMAKE_CONFIGURATION_TYPES=Release

:: 下载 TA-Lib C 代码
echo Downloading TA-Lib C source code (v%TALIB_C_VER%)...
curl -L -o talib-c.zip https://github.com/TA-Lib/ta-lib/archive/refs/tags/v%TALIB_C_VER%.zip
if %errorlevel% neq 0 (
    echo ERROR: Failed to download TA-Lib C source
    exit /B 1
)

:: 下载 TA-Lib Python 代码
echo Downloading TA-Lib Python source code (v%TALIB_PY_VER%)...
curl -L -o talib-python.zip https://github.com/TA-Lib/ta-lib-python/archive/refs/tags/TA_Lib-%TALIB_PY_VER%.zip
if %errorlevel% neq 0 (
    echo ERROR: Failed to download TA-Lib Python source
    exit /B 1
)

:: 解压 TA-Lib C 代码
echo Extracting TA-Lib C source...
tar -xf talib-c.zip
if %errorlevel% neq 0 (
    echo ERROR: Failed to extract TA-Lib C source
    exit /B 1
)

:: 解压 TA-Lib Python 代码到当前目录
echo Extracting TA-Lib Python source...
tar -xf talib-python.zip --strip-components=1
if %errorlevel% neq 0 (
    echo ERROR: Failed to extract TA-Lib Python source
    exit /B 1
)

:: 构建 TA-Lib C 库
echo Building TA-Lib C library...
pushd ta-lib-%TALIB_C_VER%

:: 创建 ta-lib 子目录并复制头文件
echo Copying header files...
mkdir include\ta-lib
copy /Y include\*.* include\ta-lib

:: 创建构建目录并开始构建
echo Creating build directory...
md _build
cd _build

echo Running CMake...
cmake.exe ..
if %errorlevel% neq 0 (
    echo ERROR: CMake configuration failed
    popd
    exit /B 1
)

echo Building with nmake...
nmake.exe /nologo all
if %errorlevel% neq 0 (
    echo ERROR: nmake build failed
    popd
    exit /B 1
)

:: 复制静态库文件
echo Copying static library file...
copy /Y /B ta-lib-static.lib ta-lib.lib

:: 返回到原始目录
popd

echo TA-Lib build completed successfully.
echo TA-Lib C library: ta-lib-%TALIB_C_VER%\_build\ta-lib.lib
echo TA-Lib Include: ta-lib-%TALIB_C_VER%\include

exit /B 0

tar -xf talib-python.zip --strip-components=1
if errorlevel 1 exit /B 1
if %errorlevel% neq 0 (
    echo ERROR: Failed to extract TA-Lib Python source
    exit /B 1
)

:: 设置错误处理，如果任何命令失败，则退出
setlocal
cd ta-lib-%TALIB_C_VER%

mkdir  include\ta-lib
:: 构建 TA-Lib C 库
echo Building TA-Lib C library...
pushd ta-lib-%TALIB_C_VER%

:: 创建 ta-lib 子目录并复制头文件
echo Copying header files...
mkdir include\ta-lib
copy /Y include\*.* include\ta-lib

md _build
cd _build

cmake.exe ..
if errorlevel 1 exit /B 1
if %errorlevel% neq 0 (
    echo ERROR: CMake configuration failed
    popd
    exit /B 1
)

nmake.exe /nologo all
if errorlevel 1 exit /B 1
if %errorlevel% neq 0 (
    echo ERROR: nmake build failed
    popd
    exit /B 1
)

copy /Y /B ta-lib-static.lib ta-lib.lib

endlocal
:: 返回到原始目录
popd

echo TA-Lib build completed successfully.
echo TA-Lib C library: ta-lib-%TALIB_C_VER%\_build\ta-lib.lib
echo TA-Lib Include: ta-lib-%TALIB_C_VER%\include

exit /B 0
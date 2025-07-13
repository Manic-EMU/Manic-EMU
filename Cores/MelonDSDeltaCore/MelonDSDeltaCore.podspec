Pod::Spec.new do |spec|
  spec.name         = "MelonDSDeltaCore"
  spec.version      = "0.1"
  spec.summary      = "Nintendo DS plug-in for Delta emulator."
  spec.description  = "iOS framework that wraps melonDS to allow playing Nintendo DS games with Delta emulator."
  spec.homepage     = "https://github.com/rileytestut/MelonDSDeltaCore"
  spec.platform     = :ios, "14.0"
  spec.source       = { :git => "https://github.com/rileytestut/MelonDSDeltaCore.git" }

  spec.author             = { "Riley Testut" => "riley@rileytestut.com" }
  spec.social_media_url   = "https://twitter.com/rileytestut"
  
  spec.source_files  = "MelonDSDeltaCore/**/*.{swift}", "MelonDSDeltaCore/MelonDSDeltaCore.h", "MelonDSDeltaCore/Bridge/MelonDSEmulatorBridge.{h,mm}", "MelonDSDeltaCore/Types/MelonDSTypes.{h,m}", "melonDS/src/*.{h,hpp,cpp}", "melonDS/src/tiny-AES-c/*.{h,hpp,c}", "melonDS/src/dolphin/Arm64Emitter.{h,cpp}", "melonDS/src/xxhash/*.{h,c}", "melonDS/src/frontend/qt_sdl/Config.{h,cpp}", "melonDS/src/sha1/*.{h,c}", "melonDS/src/fatfs/*.{h,c}", "melonDS/src/teakra/src/*.{h,cpp}", "melonDS/src/teakra/include/teakra/*.h", "melonDS/src/frontend/qt_sdl/LAN_Socket.{h,cpp}", "melonDS/src/frontend/libslirp/src/*.{h,c}", "melonDS/src/frontend/libslirp/slirp/*.h", "melonDS/src/frontend/libslirp/glib/*.{h,c}"
  spec.exclude_files = "melonDS/src/GPU3D_OpenGL.cpp", "melonDS/src/OpenGLSupport.cpp", "melonDS/src/GPU_OpenGL.cpp", "melonDS/src/ARMJIT.{h,cpp}", "melonDS/src/teakra/src/teakra_c.cpp"
  spec.public_header_files = "MelonDSDeltaCore/Types/MelonDSTypes.h", "MelonDSDeltaCore/Bridge/MelonDSEmulatorBridge.h", "MelonDSDeltaCore/MelonDSDeltaCore.h"
  spec.header_mappings_dir = ""
  spec.dependency 'ManicEmuCore'
    
  spec.xcconfig = {
    "HEADER_SEARCH_PATHS" => '"${PODS_CONFIGURATION_BUILD_DIR}" "$(PODS_ROOT)/Headers/Private/MelonDSDeltaCore/melonDS/src" "$(PODS_ROOT)/Headers/Private/MelonDSDeltaCore/melonDS/src/frontend/libslirp"',
    "USER_HEADER_SEARCH_PATHS" => '"${PODS_CONFIGURATION_BUILD_DIR}/EmulatorCore/Swift Compatibility Header" "$(PODS_ROOT)/Headers/Private/MelonDSDeltaCore/melonDS/src/teakra/include" "$(PODS_ROOT)/Headers/Private/MelonDSDeltaCore/melonDS/src/frontend"',
    "GCC_PREPROCESSOR_DEFINITIONS" => "STATIC_LIBRARY=1 _NETINET_TCP_VAR_H_ MELONDS_VERSION=" "\\" "\"0.9.5" "\\" "\"",
    "GCC_OPTIMIZATION_LEVEL" => "fast",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
  
  spec.library = 'resolv'
  
end

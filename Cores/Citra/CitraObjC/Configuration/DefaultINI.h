//
//  DefaultINI.h
//  Folium
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#pragma once

namespace DefaultINI {

const char* sdl3_config_file = R"(
[Core]
# Whether to use the Just-In-Time (JIT) compiler for CPU emulation
# 0: Interpreter (slow), 1 (default): JIT (fast)
use_cpu_jit=1

# Change the Clock Frequency of the emulated 3DS CPU.
# Underclocking can increase the performance of the game at the risk of freezing.
# Overclocking may fix lag that happens on console, but also comes with the risk of freezing.
# Range is any positive integer (but we suspect 25 - 400 is a good idea) Default is 100
cpu_clock_percentage=100

[Renderer]
# Disabling right-eye rendering can improve the performance of some games, but it may also cause issues such as screen flickering
# 0: enable, 1: disable (default)
disable_right_eye_render=1

# Whether to compile shaders on multiple worker threads (Vulkan only)
# 0: Off (default), 1: On 
async_shader_compilation=0

# Whether to emit PICA fragment shader using SPIRV or GLSL (Vulkan only)
# 0: GLSL, 1: SPIR-V (default)
spirv_shader_gen=1

# Whether to use hardware shaders to emulate 3DS shaders
# 0: Software, 1 (default): Hardware
use_hw_shader=1

# Whether to use accurate multiplication in hardware shaders
# 0: Off (Default. Faster, but causes issues in some games) 1: On (Slower, but correct)
shaders_accurate_mul=0

# Whether to use the Just-In-Time (JIT) compiler for shader emulation
# 0: Interpreter (slow), 1 (default): JIT (fast)
use_shader_jit=1

# Forces VSync on the display thread. Usually doesn't impact performance, but on some drivers it can
# so only turn this off if you notice a speed difference.
# 0: Off, 1 (default): On
use_vsync_new=1

# Reduce stuttering by storing and loading generated shaders to disk
# 0: Off, 1 (default. On)
use_disk_shader_cache=1

# Resolution scale factor
# 0: Auto (scales resolution to window size), 1: Native 3DS screen resolution, Otherwise a scale
# factor for the 3DS resolution
resolution_factor=1

# Turns on the frame limiter, which will limit frames output to the target game speed
# 0: Off, 1: On (default)
use_frame_limit=1

# Limits the speed of the game to run no faster than this value as a percentage of target speed
# 1 - 9999: Speed limit as a percentage of target game speed. 100 (default)
frame_limit=100

# The clear color of red chanel for the renderer. What shows up on the sides of the bottom screen.
# Must be in range of 0.0-1.0. Defaults to 0.0 for all.
bg_red=0.0
# The clear color of blue chanel for the renderer. What shows up on the sides of the bottom screen.
# Must be in range of 0.0-1.0. Defaults to 0.0 for all.
bg_blue=0.0
# The clear color of green chanel for the renderer. What shows up on the sides of the bottom screen.
# Must be in range of 0.0-1.0. Defaults to 0.0 for all.
bg_green=0.0

# Whether and how Stereoscopic 3D should be rendered
# 0 (default): Off, 1: Side by Side, 2: Anaglyph, 3: Interlaced, 4: Reverse Interlaced, 5: Cardboard VR
render_3d=0

# Change 3D Intensity
# 0 - 100: Intensity. 0 (default)
factor_3d=0

# 0 (default): LeftEye 1: RightEye
mono_render_option=0

# The name of the post processing shader to apply.
# Loaded from shaders if render_3d is off or side by side.
pp_shader_name=none (builtin)

# The name of the shader to apply when render_3d is anaglyph.
# Loaded from shaders/anaglyph
anaglyph_shader_name=dubois (builtin)

# Whether to enable linear filtering or not
# This is required for some shaders to work correctly
# 0: Nearest, 1 (default): Linear
filter_mode=1

# 0: None (default) 1: Anime4K 2: Bicubic 3: ScaleForce 4: xBRZ 5: MMPX
texture_filter=0

# 0: GameControlled 1: NearestNeighbor 2: Linear
texture_sampling=0 

[Utility]
# Dumps textures as PNG to dump/textures/[Title ID]/.
# 0 (default): Off, 1: On
dump_textures=0

# Reads PNG files from load/textures/[Title ID]/ and replaces textures.
# 0 (default): Off, 1: On
custom_textures=0

# Loads all custom textures into memory before booting.
# 0 (default): Off, 1: On
preload_textures=0

# Loads custom textures asynchronously with background threads.
# 0: Off, 1 (default): On
async_custom_loading=1

[Audio]
# Whether or not to enable the audio-stretching post-processing effect.
# This effect adjusts audio speed to match emulation speed and helps prevent audio stutter,
# at the cost of increasing audio latency.
# 0: No, 1 (default): Yes
enable_audio_stretching=1

# 0 (default): HLE 1: LLE 2: LLEMultithreaded
audio_emulation=0

# 0 (defalut): Off 1: On
enable_realtime_audio=0

# Output volume.
# 1.0 (default): 100%, 0.0; mute
volume=1.0

# Which audio output type to use.
# 0 (default): Auto-select, 1: No audio output, 2: Cubeb (if available), 3: OpenAL (if available), 4: SDL3 (if available)
output_type=0

# Which audio input type to use.
# 0 (default): Auto-select, 1: No audio input, 2: Static noise, 3: Cubeb (if available), 4: OpenAL (if available)
input_type=0

[Data Storage]
# Whether to create a virtual SD card.
# 1 (default): Yes, 0: No
use_virtual_sd=1

[System]
# The system model that Manic EMU will try to emulate
# 0: Old 3DS (default), 1: New 3DS
is_new_3ds=1

# Whether to use LLE system applets, if installed
# 0 (default): No, 1: Yes
lle_applets=0

# The system region that Manic EMU will use during emulation
# -1: Auto-select (default), 0: Japan, 1: USA, 2: Europe, 3: Australia, 4: China, 5: Korea, 6: Taiwan
region_value=-1

# The clock to use when Manic EMU starts
# 0: System clock (default), 1: fixed time
init_clock=0

# Time used when init_clock is set to fixed_time in the format %Y-%m-%d %H:%M:%S
# set to fixed time. Default 2000-01-01 00:00:01
# Note: 3DS can only handle times later then Jan 1 2000
init_time=946681277

# The system ticks count to use when Manic EMU starts
# 0: Random (default), 1: Fixed
init_ticks_type=0

# Tick count to use when init_ticks_type is set to Fixed.
# Defaults to 0.
init_ticks_override=0

# Plugin loader state, if enabled plugins will be loaded from the SD card.
# You can also set if homebrew apps are allowed to enable the plugin loader
plugin_loader=0
allow_plugin_loader=1

# Set the number of steps simulated per hour for the 3DS system, which may be useful for some games.
# Defaults to 0.
steps_per_hour=0

[Camera]
# The image flip to apply
# 0: None (default), 1: Horizontal, 2: Vertical, 3: Reverse
camera_outer_right_flip=0

# The image flip to apply
# 0: None (default), 1: Horizontal, 2: Vertical, 3: Reverse
camera_outer_left_flip=0

# The image flip to apply
# 0: None (default), 1: Horizontal, 2: Vertical, 3: Reverse
camera_inner_flip=0
)";
}

cmake_minimum_required(VERSION 3.16)
cmake_policy(SET CMP0074 NEW)
include(CheckIncludeFiles)

project(Aegisub)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# Explicitly set the build type to Release if no other type is specified
# on the command line.  Without this, cmake defaults to an unoptimized,
# non-debug build, which almost nobody wants.
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

## Build bundled LuaJIT with aegisub specific patches
add_executable(luajit-minilua vendor/luajit/src/host/minilua.c)
if(NOT WIN32)
    target_link_libraries(luajit-minilua m)
endif()
if(WIN32)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen"
            COMMAND luajit-minilua ../dynasm/dynasm.lua -LN -D WIN -D JIT -D FFI -D P64 -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h" vm_x86.dasc
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
        )
    else()
        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen"
            COMMAND luajit-minilua ../dynasm/dynasm.lua -LN -D WIN -D JIT -D FFI -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h" vm_x86.dasc
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
        )
    endif()
elseif(APPLE)
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen"
        COMMAND luajit-minilua ../dynasm/dynasm.lua -D P64 -D JIT -D FFI -D FPU -D HFABI -D VER= -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h" vm_x64.dasc
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
    )
else()
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen"
            COMMAND luajit-minilua ../dynasm/dynasm.lua -D P64 -D JIT -D FFI -D FPU -D HFABI -D VER= -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h" vm_x86.dasc
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
        )
    else()
        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen"
            COMMAND luajit-minilua ../dynasm/dynasm.lua -D JIT -D FFI -D FPU -D HFABI -D VER= -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h" vm_x86.dasc
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
        )
    endif()
endif()

add_executable(luajit-buildvm
    vendor/luajit/src/host/buildvm.c
    vendor/luajit/src/host/buildvm_asm.c
    vendor/luajit/src/host/buildvm_peobj.c
    vendor/luajit/src/host/buildvm_lib.c
    vendor/luajit/src/host/buildvm_fold.c

    "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/buildvm_arch.h"
)
target_compile_definitions(luajit-buildvm PRIVATE LUAJIT_ENABLE_LUA52COMPAT)
target_include_directories(luajit-buildvm PRIVATE vendor/luajit/src "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen")
if(APPLE)
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.s"
        COMMAND luajit-buildvm -m machasm -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.s"
    )
elseif(UNIX)
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.s"
        COMMAND luajit-buildvm -m elfasm -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.s"
    )
elseif(MSVC)
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.obj"
        COMMAND luajit-buildvm -m peobj -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.obj"
    )
endif()
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_ffdef.h"
    COMMAND luajit-buildvm -m ffdef -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_ffdef.h" lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_bcdef.h"
    COMMAND luajit-buildvm -m bcdef -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_bcdef.h" lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_folddef.h"
    COMMAND luajit-buildvm -m folddef -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_folddef.h" lj_opt_fold.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_recdef.h"
    COMMAND luajit-buildvm -m recdef -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_recdef.h" lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_libdef.h"
    COMMAND luajit-buildvm -m libdef -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_libdef.h" lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/jit/vmdef.lua"
    COMMAND luajit-buildvm -m vmdef -o "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/jit/vmdef.lua" lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)

add_library(luajit STATIC
    vendor/luajit/src/lib_base.c
    vendor/luajit/src/lib_math.c
    vendor/luajit/src/lib_bit.c
    vendor/luajit/src/lib_string.c
    vendor/luajit/src/lib_table.c
    vendor/luajit/src/lib_io.c
    vendor/luajit/src/lib_os.c
    vendor/luajit/src/lib_package.c
    vendor/luajit/src/lib_debug.c
    vendor/luajit/src/lib_jit.c
    vendor/luajit/src/lib_ffi.c
    vendor/luajit/src/lj_gc.c
    vendor/luajit/src/lj_err.c
    vendor/luajit/src/lj_char.c
    vendor/luajit/src/lj_bc.c
    vendor/luajit/src/lj_obj.c
    vendor/luajit/src/lj_buf.c
    vendor/luajit/src/lj_str.c
    vendor/luajit/src/lj_tab.c
    vendor/luajit/src/lj_func.c
    vendor/luajit/src/lj_udata.c
    vendor/luajit/src/lj_meta.c
    vendor/luajit/src/lj_debug.c
    vendor/luajit/src/lj_state.c
    vendor/luajit/src/lj_dispatch.c
    vendor/luajit/src/lj_vmevent.c
    vendor/luajit/src/lj_vmmath.c
    vendor/luajit/src/lj_strscan.c
    vendor/luajit/src/lj_strfmt.c
    vendor/luajit/src/lj_strfmt_num.c
    vendor/luajit/src/lj_api.c
    vendor/luajit/src/lj_profile.c
    vendor/luajit/src/lj_lex.c
    vendor/luajit/src/lj_parse.c
    vendor/luajit/src/lj_bcread.c
    vendor/luajit/src/lj_bcwrite.c
    vendor/luajit/src/lj_load.c
    vendor/luajit/src/lj_ir.c
    vendor/luajit/src/lj_opt_mem.c
    vendor/luajit/src/lj_opt_fold.c
    vendor/luajit/src/lj_opt_narrow.c
    vendor/luajit/src/lj_opt_dce.c
    vendor/luajit/src/lj_opt_loop.c
    vendor/luajit/src/lj_opt_split.c
    vendor/luajit/src/lj_opt_sink.c
    vendor/luajit/src/lj_mcode.c
    vendor/luajit/src/lj_snap.c
    vendor/luajit/src/lj_record.c
    vendor/luajit/src/lj_crecord.c
    vendor/luajit/src/lj_ffrecord.c
    vendor/luajit/src/lj_asm.c
    vendor/luajit/src/lj_trace.c
    vendor/luajit/src/lj_gdbjit.c
    vendor/luajit/src/lj_ctype.c
    vendor/luajit/src/lj_cdata.c
    vendor/luajit/src/lj_cconv.c
    vendor/luajit/src/lj_ccall.c
    vendor/luajit/src/lj_ccallback.c
    vendor/luajit/src/lj_carith.c
    vendor/luajit/src/lj_clib.c
    vendor/luajit/src/lj_cparse.c
    vendor/luajit/src/lj_lib.c
    vendor/luajit/src/lj_alloc.c
    vendor/luajit/src/lib_aux.c
    vendor/luajit/src/lib_init.c

    "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_ffdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_bcdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_folddef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_recdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen/lj_libdef.h"
    # "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/jit/vmdef.lua"
)
target_compile_definitions(luajit PRIVATE LUAJIT_ENABLE_LUA52COMPAT)
target_include_directories(luajit PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/gen" PUBLIC "vendor/luajit/src")
if(WIN32)
    target_sources(luajit PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.obj")
else()
    target_sources(luajit PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.s")
    set_property(SOURCE "${CMAKE_CURRENT_BINARY_DIR}/vendor/luajit/src/lj_vm.s" PROPERTY LANGUAGE C)
    target_link_libraries(luajit ${CMAKE_DL_LIBS})
endif()
if(APPLE)
    target_compile_definitions(luajit-buildvm PRIVATE LUAJIT_ENABLE_GC64)
    target_compile_definitions(luajit PRIVATE LUAJIT_ENABLE_GC64)
endif()

add_subdirectory(vendor/luabins)

## libaegisub
add_library(libaegisub STATIC
    libaegisub/common/parser.cpp
    libaegisub/ass/dialogue_parser.cpp
    libaegisub/ass/time.cpp
    libaegisub/ass/uuencode.cpp
    libaegisub/audio/provider.cpp
    libaegisub/audio/provider_convert.cpp
    libaegisub/audio/provider_dummy.cpp
    libaegisub/audio/provider_hd.cpp
    libaegisub/audio/provider_lock.cpp
    libaegisub/audio/provider_pcm.cpp
    libaegisub/audio/provider_ram.cpp
    libaegisub/common/cajun/elements.cpp
    libaegisub/common/cajun/reader.cpp
    libaegisub/common/cajun/writer.cpp
    libaegisub/lua/modules/lfs.cpp
    libaegisub/lua/modules/re.cpp
    libaegisub/lua/modules/unicode.cpp
    libaegisub/lua/modules/lpeg.c
    libaegisub/lua/modules.cpp
    libaegisub/lua/script_reader.cpp
    libaegisub/lua/utils.cpp
    libaegisub/common/calltip_provider.cpp
    libaegisub/common/character_count.cpp
    libaegisub/common/charset.cpp
    libaegisub/common/charset_6937.cpp
    libaegisub/common/charset_conv.cpp
    libaegisub/common/color.cpp
    libaegisub/common/file_mapping.cpp
    libaegisub/common/format.cpp
    libaegisub/common/fs.cpp
    libaegisub/common/hotkey.cpp
    libaegisub/common/io.cpp
    libaegisub/common/json.cpp
    libaegisub/common/kana_table.cpp
    libaegisub/common/karaoke_matcher.cpp
    libaegisub/common/keyframe.cpp
    libaegisub/common/line_iterator.cpp
    libaegisub/common/log.cpp
    libaegisub/common/mru.cpp
    libaegisub/common/option.cpp
    libaegisub/common/option_value.cpp
    libaegisub/common/path.cpp
    libaegisub/common/thesaurus.cpp
    libaegisub/common/util.cpp
    libaegisub/common/vfr.cpp
    libaegisub/common/ycbcr_conv.cpp
    libaegisub/common/dispatch.cpp
)
target_compile_features(libaegisub PUBLIC cxx_std_11)
if(UNIX)
    target_sources(libaegisub PRIVATE
        libaegisub/unix/access.cpp
        libaegisub/unix/fs.cpp
        libaegisub/unix/log.cpp
        libaegisub/unix/path.cpp
        libaegisub/unix/util.cpp
    )
    set_property(
        SOURCE libaegisub/unix/path.cpp
        PROPERTY COMPILE_DEFINITIONS
            P_DATA="${CMAKE_INSTALL_PREFIX}/share/aegisub/"
    )
elseif(WIN32)
    target_sources(libaegisub PRIVATE
        libaegisub/windows/access.cpp
        libaegisub/windows/charset_conv_win.cpp
        libaegisub/windows/fs.cpp
        libaegisub/windows/lagi_pre.cpp
        libaegisub/windows/log_win.cpp
        libaegisub/windows/path_win.cpp
        libaegisub/windows/util_win.cpp
    )
endif()
if(APPLE)
    target_sources(libaegisub PRIVATE
        libaegisub/osx/dispatch.mm
        libaegisub/osx/spellchecker.mm
        libaegisub/osx/util.mm)
endif()
set_target_properties(libaegisub PROPERTIES PREFIX "")
target_compile_definitions(libaegisub PRIVATE CMAKE_BUILD)
target_include_directories(libaegisub PUBLIC "libaegisub/include")
if(APPLE)
    # CMake on macOS currently does not support pch with objc, so use the old way
    target_compile_options(libaegisub PRIVATE -include "${PROJECT_SOURCE_DIR}/libaegisub/lagi_pre.h")
else()
    target_precompile_headers(libaegisub PRIVATE "libaegisub/lagi_pre.h")
endif()
target_link_libraries(libaegisub PRIVATE luajit luabins)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config.cpp" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config.h"
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config_platform.json"
    COMMAND luajit-minilua "${PROJECT_SOURCE_DIR}/tools/respack.lua" manifest.respack default_config.cpp default_config.h
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc"
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/bitmap.cpp" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/bitmap.h"
    COMMAND luajit-minilua ../../tools/respack.lua manifest.respack "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/bitmap.cpp" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/bitmap.h"
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/src/bitmaps
)

add_subdirectory("vendor/csri")

## Aegisub
add_executable(Aegisub WIN32
    "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/bitmap.h"
    "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config.h"
    
    src/command/app.cpp
    src/command/audio.cpp
    src/command/automation.cpp
    src/command/command.cpp
    src/command/edit.cpp
    src/command/grid.cpp
    src/command/help.cpp
    src/command/keyframe.cpp
    src/command/recent.cpp
    src/command/subtitle.cpp
    src/command/time.cpp
    src/command/timecode.cpp
    src/command/tool.cpp
    src/command/video.cpp
    src/command/vis_tool.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/bitmap.cpp"
    "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config.cpp"
    src/libresrc/libresrc.cpp
    src/dialog_about.cpp
    src/dialog_align.cpp
    src/dialog_attachments.cpp
    src/dialog_automation.cpp
    src/dialog_autosave.cpp
    src/dialog_colorpicker.cpp
    src/dialog_detached_video.cpp
    src/dialog_dummy_video.cpp
    src/dialog_export.cpp
    src/dialog_export_ebu3264.cpp
    src/dialog_fonts_collector.cpp
    src/dialog_jumpto.cpp
    src/dialog_kara_timing_copy.cpp
    src/dialog_log.cpp
    src/dialog_paste_over.cpp
    src/dialog_progress.cpp
    src/dialog_properties.cpp
    src/dialog_resample.cpp
    src/dialog_search_replace.cpp
    src/dialog_selected_choices.cpp
    src/dialog_selection.cpp
    src/dialog_shift_times.cpp
    src/dialog_spellchecker.cpp
    src/dialog_style_editor.cpp
    src/dialog_style_manager.cpp
    src/dialog_styling_assistant.cpp
    src/dialog_text_import.cpp
    src/dialog_timing_processor.cpp
    src/dialog_translation.cpp
    src/dialog_video_details.cpp
    src/dialog_video_properties.cpp
    src/subtitle_format.cpp
    src/subtitle_format_ass.cpp
    src/subtitle_format_ebu3264.cpp
    src/subtitle_format_encore.cpp
    src/subtitle_format_microdvd.cpp
    src/subtitle_format_mkv.cpp
    src/subtitle_format_srt.cpp
    src/subtitle_format_ssa.cpp
    src/subtitle_format_transtation.cpp
    src/subtitle_format_ttxt.cpp
    src/subtitle_format_txt.cpp
    src/visual_tool.cpp
    src/visual_tool_clip.cpp
    src/visual_tool_cross.cpp
    src/visual_tool_drag.cpp
    src/visual_tool_rotatexy.cpp
    src/visual_tool_rotatez.cpp
    src/visual_tool_scale.cpp
    src/visual_tool_vector_clip.cpp
    src/MatroskaParser.c
    src/aegisublocale.cpp
    src/ass_attachment.cpp
    src/ass_dialogue.cpp
    src/ass_entry.cpp
    src/ass_export_filter.cpp
    src/ass_exporter.cpp
    src/ass_file.cpp
    src/ass_karaoke.cpp
    src/ass_override.cpp
    src/ass_parser.cpp
    src/ass_style.cpp
    src/ass_style_storage.cpp
    src/async_video_provider.cpp
    src/audio_box.cpp
    src/audio_colorscheme.cpp
    src/audio_controller.cpp
    src/audio_display.cpp
    src/audio_karaoke.cpp
    src/audio_marker.cpp
    src/audio_player.cpp
    src/audio_provider_factory.cpp
    src/audio_renderer.cpp
    src/audio_renderer_spectrum.cpp
    src/audio_renderer_waveform.cpp
    src/audio_timing_dialogue.cpp
    src/audio_timing_karaoke.cpp
    src/auto4_base.cpp
    src/auto4_lua.cpp
    src/auto4_lua_assfile.cpp
    src/auto4_lua_dialog.cpp
    src/auto4_lua_progresssink.cpp
    src/base_grid.cpp
    src/charset_detect.cpp
    src/colorspace.cpp
    src/colour_button.cpp
    src/compat.cpp
    src/context.cpp
    src/export_fixstyle.cpp
    src/export_framerate.cpp
    src/fft.cpp
    src/font_file_lister.cpp
    src/frame_main.cpp
    src/gl_text.cpp
    src/gl_wrap.cpp
    src/grid_column.cpp
    src/help_button.cpp
    src/hotkey.cpp
    src/hotkey_data_view_model.cpp
    src/image_position_picker.cpp
    src/initial_line_state.cpp
    src/main.cpp
    src/menu.cpp
    src/mkv_wrap.cpp
    src/pen.cpp
    src/persist_location.cpp
    src/preferences.cpp
    src/preferences_base.cpp
    src/project.cpp
    src/resolution_resampler.cpp
    src/search_replace_engine.cpp
    src/selection_controller.cpp
    src/spellchecker.cpp
    src/spline.cpp
    src/spline_curve.cpp
    src/string_codec.cpp
    src/subs_controller.cpp
    src/subs_edit_box.cpp
    src/subs_edit_ctrl.cpp
    src/subs_preview.cpp
    src/subtitles_provider.cpp
    src/subtitles_provider_libass.cpp
    src/text_file_reader.cpp
    src/text_file_writer.cpp
    src/text_selection_controller.cpp
    src/thesaurus.cpp
    src/timeedit_ctrl.cpp
    src/toggle_bitmap.cpp
    src/toolbar.cpp
    src/tooltip_manager.cpp
    src/utils.cpp
    src/validators.cpp
    src/vector2d.cpp
    src/version.cpp
    src/video_box.cpp
    src/video_controller.cpp
    src/video_display.cpp
    src/video_frame.cpp
    src/video_out_gl.cpp
    src/video_provider_cache.cpp
    src/video_provider_dummy.cpp
    src/video_provider_manager.cpp
    src/video_provider_yuv4mpeg.cpp
    src/video_slider.cpp
    src/visual_feature.cpp
)
target_link_libraries(Aegisub PRIVATE ${CMAKE_DL_LIBS} libaegisub luajit)
target_compile_definitions(Aegisub PRIVATE CMAKE_BUILD)
target_include_directories(Aegisub PRIVATE "src/libresrc" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc")
if(APPLE)
    # CMake on macOS currently does not support pch with objc, so use the old way
    target_compile_options(Aegisub PRIVATE -include "${PROJECT_SOURCE_DIR}/src/agi_pre.h")
else()
    target_precompile_headers(Aegisub PRIVATE "src/agi_pre.h")
endif()

if(WIN32)
    if(NOT EXISTS "${PROJECT_SOURCE_DIR}/build/git_version.h")
        message(SEND_ERROR
            "build/git_version.h not found.\n"
            "Automatic generation of build/git_version.h is not supported on Windows. Please run\n"
            "    build/version.sh .\n"
            "at the source directory from an environment with bash and git. You may use WSL, msys (git bash), or Cygwin."
        )
    else()
        target_include_directories(Aegisub PRIVATE "build")
    endif()
else()
    add_custom_target(git_version build/version.sh .
        BYPRODUCTS "${PROJECT_SOURCE_DIR}/build/git_version.h" "${PROJECT_SOURCE_DIR}/build/git_version.xml"
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    )
    add_dependencies(Aegisub git_version)
    target_include_directories(Aegisub PRIVATE "build")
endif()

option(WITH_BUILD_CREDIT "Whether show build credit in about dialog")
if(WITH_BUILD_CREDIT)
    set(BUILD_CREDIT "" CACHE STRING "Build credit shown in about dialog")
    target_compile_definitions(Aegisub PRIVATE "BUILD_CREDIT=${BUILD_CREDIT}")
else()
    unset(BUILD_CREDIT CACHE)
endif()

if(MSVC)
    add_definitions("/DNOMINMAX /DINITGUID")
    target_link_libraries(Aegisub LINK_PRIVATE Usp10)
    #target_sources(Aegisub PRIVATE src/res/res.rc src/res/strings.rc src/crash_writer_minidump.cpp)
    target_sources(Aegisub PRIVATE src/res/res.rc src/res/strings.rc src/crash_writer.cpp src/dpi_aware.manifest)
    set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT Aegisub)
elseif(APPLE)
    target_include_directories(Aegisub PRIVATE src)  # For src/retina_helper.h
    target_sources(Aegisub PRIVATE src/crash_writer.cpp src/osx/osx_utils.mm src/osx/retina_helper.mm)
else()
    target_sources(Aegisub PRIVATE src/crash_writer.cpp)
endif()

if(WIN32)
    target_sources(Aegisub PRIVATE src/font_file_lister_gdi.cpp)
elseif(APPLE)
    target_sources(Aegisub PRIVATE src/font_file_lister_coretext.mm)
else()
    find_package(Fontconfig REQUIRED)
    target_link_libraries(Aegisub PRIVATE "Fontconfig::Fontconfig")
    target_sources(Aegisub PRIVATE src/font_file_lister_fontconfig.cpp)
endif()

find_package(ass REQUIRED)
target_include_directories(Aegisub PRIVATE ${ass_INCLUDE_DIRS})
target_link_libraries(Aegisub LINK_PRIVATE ${ass_LIBRARIES})

find_package(Boost REQUIRED container filesystem locale regex thread)
target_link_libraries(libaegisub PRIVATE "Boost::locale" "Boost::regex" "Boost::thread")
target_link_libraries(libaegisub PUBLIC "Boost::headers" "Boost::container" "Boost::filesystem")
target_link_libraries(Aegisub PRIVATE "Boost::headers" "Boost::container" "Boost::filesystem" "Boost::locale" "Boost::regex")

find_package(OpenGL REQUIRED)
target_link_libraries(Aegisub PRIVATE "OpenGL::GL")
check_include_files(OpenGL/gl.h HAVE_OPENGL_GL_H)
if(HAVE_OPENGL_GL_H)
    target_compile_definitions(Aegisub PRIVATE "HAVE_OPENGL_GL_H")
endif()

find_package(Iconv REQUIRED)
target_link_libraries(libaegisub PRIVATE "Iconv::Iconv")

find_package(ICU REQUIRED uc in)
target_link_libraries(libaegisub PRIVATE "ICU::uc")
target_link_libraries(Aegisub PRIVATE "ICU::uc" "ICU::in")

find_package(wxWidgets REQUIRED adv base core gl stc xml)
option(WITH_WXSTC "Enable wxStyledTextCtrl support" ON)
if(WITH_WXSTC)
    target_compile_definitions(Aegisub PRIVATE "WITH_WXSTC")
    target_sources(Aegisub PRIVATE src/subs_edit_ctrl_stc.cpp)
endif()
include(${wxWidgets_USE_FILE})
target_link_libraries(Aegisub LINK_PRIVATE ${wxWidgets_LIBRARIES})

find_package(ZLIB REQUIRED)
target_link_libraries(Aegisub PRIVATE "ZLIB::ZLIB")

find_package(ALSA)
option(WITH_ALSA "Enable ALSA support" ${ALSA_FOUND})
if(WITH_ALSA)
    find_package(ALSA REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_ALSA")
    target_link_libraries(Aegisub PRIVATE "ALSA::ALSA")
    target_sources(Aegisub PRIVATE src/audio_player_alsa.cpp)
endif()

find_package(AviSynth)
option(WITH_AVISYNTH "Enable AviSynth support" ${AviSynth_FOUND})
if(WITH_AVISYNTH)
    find_package(AviSynth REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_AVISYNTH")
    target_include_directories(Aegisub PRIVATE ${AviSynth_INCLUDE_DIRS})
    if(WIN32)
        target_link_libraries(Aegisub LINK_PRIVATE Vfw32)
    endif()
    get_filename_component(Avisynth_LIBRARY_NAME "${AviSynth_SHARED_LIBRARY}" NAME CACHE)
    target_compile_definitions(Aegisub PRIVATE "AVISYNTH_SO=\"${Avisynth_LIBRARY_NAME}\"")
    target_sources(Aegisub PRIVATE src/audio_provider_avs.cpp src/avisynth_wrap.cpp src/video_provider_avs.cpp)
endif()

option(WITH_CSRI "Enable CSRI support" ON)
if(WITH_CSRI)
    target_compile_definitions(Aegisub PRIVATE "WITH_CSRI")
    target_link_libraries(Aegisub PRIVATE csri)
    target_sources(Aegisub PRIVATE src/subtitles_provider_csri.cpp)
endif()

if(WIN32)
    option(WITH_DIRECTSOUND "Enable DirectSound support" ON)
    if(WITH_DIRECTSOUND)
        target_compile_definitions(Aegisub PRIVATE "WITH_DIRECTSOUND")
        target_link_libraries(Aegisub LINK_PRIVATE dsound)
        target_sources(Aegisub PRIVATE src/audio_player_dsound.cpp src/audio_player_dsound2.cpp)
    endif()
    option(WITH_XAUDIO2 "Enable XAudio2 support" ON)
    if(WITH_XAUDIO2)
        target_compile_definitions(Aegisub PRIVATE "WITH_XAUDIO2")
        target_sources(Aegisub PRIVATE src/audio_player_xaudio2.cpp)
        option(XAUDIO2_REDIST "Use XAudio redistributable")
        if(XAUDIO2_REDIST)
            find_package(XAudio2redist REQUIRED)
            target_compile_definitions(Aegisub PRIVATE "XAUDIO2_REDIST")
            target_include_directories(Aegisub PRIVATE ${XAudio2redist_INCLUDE_DIRS})
            target_link_libraries(Aegisub PRIVATE ${XAudio2redist_LIBRARIES})
        endif()
    endif()
else()
    set(WITH_DIRECTSOUND OFF)
    set(WITH_XAUDIO2 OFF)
endif()

find_package(FFMS2)
option(WITH_FFMS2 "Enable FFMS2 support" ${FFMS2_FOUND})
if(WITH_FFMS2)
    find_package(FFMS2 REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_FFMS2")
    target_include_directories(Aegisub PRIVATE ${FFMS2_INCLUDE_DIRS})
    target_link_libraries(Aegisub LINK_PRIVATE ${FFMS2_LIBRARIES})
    target_sources(Aegisub PRIVATE src/audio_provider_ffmpegsource.cpp src/ffmpegsource_common.cpp src/video_provider_ffmpegsource.cpp)
else()
    message(SEND_ERROR
        "No supported video/audio reader interface was enabled.\n"
        "You will not be able to open any video or audio files in Aegisub unless you install a supported video/audio provider.\n"
        "You will however still be able to open \"dummy\" video, ie. a blank, virtual video clip with subtitles overlaid.\n"
        "Currently we only support one video/audio provider on non-Windows systems:\n"
        " - FFMS2\n"
        "   * http://github.com/FFMS/ffms2\n"
    )
endif()

find_package(FFTW)
option(WITH_FFTW3 "Enable fftw support" ${FFTW_FOUND})
if(WITH_FFTW3)
    find_package(FFTW REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_FFTW3")
    target_include_directories(Aegisub PRIVATE ${FFTW_INCLUDES})
    target_link_libraries(Aegisub LINK_PRIVATE ${FFTW_LIBRARIES})
endif()

find_package(Hunspell)
option(WITH_HUNSPELL "Enable Hunspell support" ${HUNSPELL_FOUND})
if(WITH_HUNSPELL)
    find_package(Hunspell REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_HUNSPELL")
    target_link_libraries(Aegisub PRIVATE "hunspell")
    target_sources(Aegisub PRIVATE src/spellchecker_hunspell.cpp)
endif()

find_package(PulseAudio)
option(WITH_LIBPULSE "Enable PulseAudio support" ${PULSEAUDIO_FOUND})
if(WITH_LIBPULSE)
    find_package(PulseAudio REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_LIBPULSE")
    target_include_directories(Aegisub PRIVATE ${PULSEAUDIO_INCLUDE_DIR})
    target_link_libraries(Aegisub LINK_PRIVATE ${PULSEAUDIO_LIBRARY})
    target_sources(Aegisub PRIVATE src/audio_player_pulse.cpp)
endif()

find_package(OpenAL)
option(WITH_OPENAL "Enable OpenAL support" ${OPENAL_FOUND})
if(WITH_OPENAL)
    find_package(OpenAL REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_OPENAL")
    target_include_directories(Aegisub PRIVATE ${OPENAL_INCLUDE_DIR})
    target_link_libraries(Aegisub LINK_PRIVATE ${OPENAL_LIBRARY})
    target_sources(Aegisub PRIVATE src/audio_player_openal.cpp)
endif()

find_package(OSS)
option(WITH_OSS "Enable OSS support" ${OSS_FOUND})
if(WITH_OSS)
    find_package(OSS REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_OSS")
    target_include_directories(Aegisub PRIVATE ${OSS_INCLUDE_DIRS})
    target_sources(Aegisub PRIVATE src/audio_player_oss.cpp)
endif()

find_package(PortAudio)
option(WITH_PORTAUDIO "Enable PortAudio support" ${PortAudio_FOUND})
if(WITH_PORTAUDIO)
    find_package(PortAudio REQUIRED)
    target_compile_definitions(Aegisub PRIVATE "WITH_PORTAUDIO")
    target_include_directories(Aegisub PRIVATE ${PortAudio_INCLUDE_DIRS})
    target_link_libraries(Aegisub LINK_PRIVATE ${PortAudio_LIBRARIES})
    target_sources(Aegisub PRIVATE src/audio_player_portaudio.cpp)
endif()

option(WITH_STARTUPLOG "Enable startup log")
if(WITH_STARTUPLOG)
    target_compile_definitions(Aegisub PRIVATE "WITH_STARTUPLOG")
endif()

find_package(uchardet)
option(WITH_UCHARDET "Enable uchardet support" ${uchardet_FOUND})
if(WITH_UCHARDET)
    find_package(uchardet REQUIRED)
    target_compile_definitions(libaegisub PRIVATE "WITH_UCHARDET")
    target_include_directories(libaegisub PRIVATE ${uchardet_INCLUDE_DIRS})
    target_link_libraries(libaegisub PRIVATE ${uchardet_LIBRARIES})
endif()

option(WITH_UPDATE_CHECKER "Enable update checker")
if(WITH_UPDATE_CHECKER)
    set(UPDATE_CHECKER_SERVER "\"updates.aegisub.org\"" CACHE STRING "Server for the update checker")
    set(UPDATE_CHECKER_BASE_URL "\"/trunk\"" CACHE STRING "Base path for the update checker")
    target_compile_definitions(Aegisub PRIVATE "WITH_UPDATE_CHECKER" "UPDATE_CHECKER_SERVER=${UPDATE_CHECKER_SERVER}" "UPDATE_CHECKER_BASE_URL=${UPDATE_CHECKER_BASE_URL}")
    target_sources(Aegisub PRIVATE src/dialog_version_check.cpp)
endif()

if(WIN32)
    if(WITH_XAUDIO2)
        set(DEFAULT_PLAYER_AUDIO "XAudio2" CACHE STRING "Default audio player")
    elseif(WITH_DIRECTSOUND)
        set(DEFAULT_PLAYER_AUDIO "DirectSound" CACHE STRING "Default audio player")
    else()
        message(SEND_ERROR
            "No supported audio player interface was enabled.\n"
            "If you want audio support in Aegisub you need to enable one of these audio players:\n"
            " - XAudio2\n"
            " - DirectSound\n"
            "\n"
        )
        set(DEFAULT_PLAYER_AUDIO "NONE" CACHE STRING "Default audio player")
    endif()
    configure_file("src/libresrc/default_config_win.json.in" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config_platform.json" @ONLY)
else()
    if(WITH_LIBPULSE)
        set(DEFAULT_PLAYER_AUDIO "PulseAudio" CACHE STRING "Default audio player")
    elseif(WITH_ALSA)
        set(DEFAULT_PLAYER_AUDIO "ALSA" CACHE STRING "Default audio player")
    elseif(WITH_OPENAL)
        set(DEFAULT_PLAYER_AUDIO "OpenAL" CACHE STRING "Default audio player")
    elseif(WITH_PORTAUDIO)
        set(DEFAULT_PLAYER_AUDIO "PortAudio" CACHE STRING "Default audio player")
    elseif(WITH_OSS)
        set(DEFAULT_PLAYER_AUDIO "OSS" CACHE STRING "Default audio player")
    else()
        message(SEND_ERROR
            "No supported audio player interface was enabled.\n"
            "If you want audio support in Aegisub you need to install one of these libraries:\n"
            " - PulseAudio\n"
            "   * http://pulseaudio.org/\n"
            " - ALSA (Linux only)\n"
            "   * http://www.alsa-project.org/\n"
            " - PortAudio (version 19 only)\n"
            "   * http://www.portaudio.com/\n"
            "\n"
        )
        set(DEFAULT_PLAYER_AUDIO "NONE" CACHE STRING "Default audio player")
    endif()
    configure_file("src/libresrc/default_config_platform.json.in" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config_platform.json" @ONLY)
endif()
configure_file("src/libresrc/default_config.json" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_config.json" COPYONLY)
configure_file("src/libresrc/default_hotkey.json" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_hotkey.json" COPYONLY)
configure_file("src/libresrc/default_menu.json" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_menu.json" COPYONLY)
configure_file("src/libresrc/default_mru.json" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_mru.json" COPYONLY)
configure_file("src/libresrc/default_toolbar.json" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/default_toolbar.json" COPYONLY)
configure_file("src/libresrc/manifest.respack" "${CMAKE_CURRENT_BINARY_DIR}/src/libresrc/manifest.respack" COPYONLY)

if(NOT WIN32)
    set(AEGISUB_COMMAND "aegisub" CACHE STRING "The executable name of Aegisub")
    set_target_properties(Aegisub PROPERTIES OUTPUT_NAME "${AEGISUB_COMMAND}")
    configure_file("packages/desktop/aegisub.desktop.template.in" "aegisub.desktop" @ONLY)
    install(FILES "${CMAKE_BINARY_DIR}/aegisub.desktop" DESTINATION "share/applications")
    install(FILES "packages/desktop/16x16.png" DESTINATION "share/icons/hicolor/16x16/apps" RENAME aegisub.png)
    install(FILES "packages/desktop/22x22.png" DESTINATION "share/icons/hicolor/22x22/apps" RENAME aegisub.png)
    install(FILES "packages/desktop/24x24.png" DESTINATION "share/icons/hicolor/24x24/apps" RENAME aegisub.png)
    install(FILES "packages/desktop/32x32.png" DESTINATION "share/icons/hicolor/32x32/apps" RENAME aegisub.png)
    install(FILES "packages/desktop/48x48.png" DESTINATION "share/icons/hicolor/48x48/apps" RENAME aegisub.png)
    install(FILES "packages/desktop/64x64.png" DESTINATION "share/icons/hicolor/64x64/apps" RENAME aegisub.png)
    install(FILES "packages/desktop/scalable.svg" DESTINATION "share/icons/hicolor/scalable/apps" RENAME aegisub.svg)
endif()
install(TARGETS Aegisub DESTINATION bin)

set(WITH_TEST OFF CACHE BOOL "Enable unit tests")
if(WITH_TEST)
    include("CMakeLists.test.txt")
endif()

message(STATUS "\n"
    "Configure settings\n"
    "  Install prefix:        ${CMAKE_INSTALL_PREFIX}\n"
    "  CFLAGS                 ${CMAKE_C_FLAGS}\n"
    "  CXXFLAGS               ${CMAKE_CXX_FLAGS}\n"
    "\n"
    "Default Settings\n"
    "  Audio Player:          ${DEFAULT_PLAYER_AUDIO}\n"
    "\n"
    "Audio Players\n"
    "  ALSA:                  ${WITH_ALSA}\n"
    "  DirectSound:           ${WITH_DIRECTSOUND}\n"
    "  DirectSound-old:       ${WITH_DIRECTSOUND}\n"
    "  XAudio2:               ${WITH_XAUDIO2}\n"
    "  OpenAL:                ${WITH_OPENAL}\n"
    "  OSS:                   ${WITH_OSS}\n"
    "  PortAudio:             ${WITH_PORTAUDIO}\n"
    "  PulseAudio:            ${WITH_LIBPULSE}\n"
    "\n"
    "Misc Packages\n"
    "  AviSynth:              ${WITH_AVISYNTH}\n"
    "  CSRI:                  ${WITH_CSRI}\n"
    "  FFMS2:                 ${WITH_FFMS2}\n"
    "  FFTW3:                 ${WITH_FFTW3}\n"
    "  Hunspell:              ${WITH_HUNSPELL}\n"
    "  uchardet:              ${WITH_UCHARDET}\n"
    "  wxStyledTextCtrl:      ${WITH_WXSTC}\n"
    "  LuaJIT:                bundled\n"
    "\n"
    "Options\n"
    "  Startup log:           ${WITH_STARTUPLOG}\n"
    "  Update checker:        ${WITH_UPDATE_CHECKER}\n"
    "  Tests:                 ${WITH_TEST}\n"
    "\n"
)

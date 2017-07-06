cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

project (gala-popup-window)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

enable_testing ()

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22" MINIMUM)
include (ValaPrecompile)

find_package (PkgConfig)
pkg_check_modules(DEPS REQUIRED gala granite gl)
add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})

include (GNUInstallDirs)
set (PLUGIN_DATA_DIR "${CMAKE_INSTALL_FULL_DATAROOTDIR}/gala-popup-window")

configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)

vala_precompile(VALA_C
	src/Main.vala
	src/SelectionArea.vala
	src/PopupWindow.vala
	src/ShadowEffect.vala
	src/MoveAction.vala
	src/config.vala
PACKAGES
	gala
	clutter-gtk-1.0
	granite
OPTIONS
	--vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi
)

add_library (${CMAKE_PROJECT_NAME} SHARED ${VALA_C})
target_link_libraries (${CMAKE_PROJECT_NAME} ${DEPS_LIBRARY} m)

install (TARGETS ${CMAKE_PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}/gala/plugins)

include (GSettings)
add_schema ("data/org.pantheon.desktop.gala.plugins.popup-window.gschema.xml")

install (FILES ${CMAKE_SOURCE_DIR}/data/resize.svg DESTINATION ${PLUGIN_DATA_DIR})

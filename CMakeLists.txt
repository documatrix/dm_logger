### CMakeLists automatically created with AutoVala
### Do not edit

project (dm_logger)
cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.8)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
option(ICON_UPDATE "Update the icon cache after installing" ON)
option(BUILD_VALADOC "Build API documentation if Valadoc is available" OFF)

set( DM_LOGGER_MAJOR 1 )
set( DM_LOGGER_MINOR 0 )
set( DM_LOGGER_RELEASE 0 )
set( DM_LOGGER_NAME dm_logger-${DM_LOGGER_MAJOR}.${DM_LOGGER_MINOR} )
set( DM_LOGGER_VERSION ${DM_LOGGER_MAJOR}.${DM_LOGGER_MINOR}.${DM_LOGGER_RELEASE} )

set(HAVE_VALADOC OFF)
if(BUILD_VALADOC)
	find_package(Valadoc)
	if(VALADOC_FOUND)
		set(HAVE_VALADOC ON)
		include(Valadoc)
	else()
		message("Valadoc not found, will not build documentation")
	endif()
endif()

find_package(PkgConfig)

set (MODULES_TO_CHECK glib-2.0 dmtestlib-1.0 gobject-2.0 gio-2.0 gthread-2.0 zlib open_dmlib-1.0)
pkg_check_modules(DEPS REQUIRED ${MODULES_TO_CHECK})

set( LIBS )
foreach( PKGLIB ${DEPS_LIBRARIES} )
  find_library( _LIB_${PKGLIB} ${PKGLIB} PATHS ${DEPS_LIBRARY_DIRS})
  list( APPEND LIBS ${_LIB_${PKGLIB}} )
endforeach( PKGLIB )

add_definitions (${DEPS_CFLAGS})
link_directories ( ${DEPS_LIBRARY_DIRS} )
link_libraries ( ${LIBS} )


set( VAPIDIRS_ARGS "" )
if( NOT ${VAPIDIRS} STREQUAL "" )
  string( REPLACE ":" ";" VAPIDIRS_LIST ${VAPIDIRS} )
  foreach ( VAPIDIR ${VAPIDIRS_LIST} )
    set( VAPIDIRS_ARGS ${VAPIDIRS_ARGS} "--vapidir=${VAPIDIR}" )
  endforeach ( VAPIDIR )
endif()

add_subdirectory(src)
add_subdirectory(tests)
add_subdirectory(doc)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/dm_logger")
set (GETTEXT_PACKAGE "dm_logger")
set (CMAKE_C_FLAGS "-g -O3")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (${DEPS_CFLAGS})
include_directories( ${CMAKE_SOURCE_DIR}/src )
link_libraries ( ${DEPS_LIBRARIES} )
link_libraries ( ${DM_LOGGER_NAME} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
link_directories ( ${CMAKE_SOURCE_DIR}/src )
find_package (Vala REQUIRED)
include( UseVala )

set (VALA_PACKAGES ${VALA_PACKAGES} gio-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} glib-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gobject-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} zlib)
set (VALA_PACKAGES ${VALA_PACKAGES} posix)
set (VALA_PACKAGES ${VALA_PACKAGES} magick_wand)
#set (VALA_PACKAGES ${VALA_PACKAGES} dm_logger-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} dmtestlib-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} open_dmlib-1.0)

set (TEST_DM_LOGGER_SOURCES ${TEST_DM_LOGGER_SOURCES} test_dm_logger.vala) 

vala_precompile(TEST_DM_LOGGER_VALA_C
  ${TEST_DM_LOGGER_SOURCES}
PACKAGES
  ${VALA_PACKAGES} ${DM_LOGGER_NAME}
OPTIONS
  --thread --vapidir=${CMAKE_INSTALL_PREFIX}/share/vala/vapi --vapidir=../include --vapidir=${CMAKE_SOURCE_DIR}/src -g
)

add_executable(
  test_dm_logger
  ${TEST_DM_LOGGER_VALA_C}
)

install(
TARGETS
  test_dm_logger
RUNTIME DESTINATION
  bin/
)

if(HAVE_VALADOC)
  valadoc(dm_logger
    ${CMAKE_BINARY_DIR}/valadoc/dm_logger
    ${APP_SOURCES}
  PACKAGES
    ${VALA_PACKAGES}
  CUSTOM_VAPIS
    ${CUSTOM_VAPIS_LIST}
  )
  install(DIRECTORY
    ${CMAKE_BINARY_DIR}/valadoc
  DESTINATION
    share/doc/dm_logger
  )
endif()

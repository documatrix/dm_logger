set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/dm_logger")
set (GETTEXT_PACKAGE "dm_logger")
set (CMAKE_C_FLAGS "-g -O3")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
find_package (Vala REQUIRED)
include( UseVala )

set (VALA_PACKAGES ${VALA_PACKAGES} gio-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} glib-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gobject-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} dmtestlib-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} posix)
set (VALA_PACKAGES ${VALA_PACKAGES} open_dmlib-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} zlib)

set (DM_LOGGER_SOURCES dm_logger.vala)
set (DM_LOGREADER_SOURCES dm_logreader.vala)

vala_precompile(DM_LOGGER_VALA_C
  ${DM_LOGGER_SOURCES}
PACKAGES
  ${VALA_PACKAGES}
GENERATE_VAPI
  ${DM_LOGGER_NAME}
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
GENERATE_HEADER
  dm_logger
OPTIONS
  --thread -g --vapidir=${CMAKE_INSTALL_PREFIX}/share/vala/vapi
  ${CMAKE_VALA_OPTS} ${VAPIDIRS_ARGS}
)

vala_precompile(DM_LOGREADER_VALA_C
  ${DM_LOGREADER_SOURCES}
PACKAGES
  ${VALA_PACKAGES}
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST} dm_logger-1.0.vapi
OPTIONS
  --thread -g --vapidir=${CMAKE_INSTALL_PREFIX}/share/vala/vapi
  ${CMAKE_VALA_OPTS} ${VAPIDIRS_ARGS}
)

add_library(
  ${DM_LOGGER_NAME} SHARED
  ${DM_LOGGER_VALA_C}
)
add_executable(
  dm_logreader
  ${DM_LOGREADER_VALA_C}
)
target_link_libraries( dm_logreader dm_logger-1.0 )

# CREATE PKGCONFIG FILES
if(NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR lib)
endif(NOT DEFINED CMAKE_INSTALL_LIBDIR)
set(prefix       ${CMAKE_INSTALL_PREFIX})
set(exec_prefix ${CMAKE_INSTALL_PREFIX})
set(libdir       ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
set(includedir  ${CMAKE_INSTALL_PREFIX}/include)
set(LIBS         "")
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libdm_logger.pc.in
  ${CMAKE_CURRENT_BINARY_DIR}/${DM_LOGGER_NAME}.pc @ONLY)


if(${CMAKE_SYSTEM_NAME} STREQUAL Windows)
  # Install dll object
  install(
    TARGETS
      ${DM_LOGGER_NAME}
    DESTINATION
      bin/ 
    )
else()
  # Install shared object
  install(
    TARGETS
      ${DM_LOGGER_NAME}
    LIBRARY DESTINATION
    lib/
  )
endif( )


# Install dm_logreader and preprocess_logger.pl
install(
TARGETS
  dm_logreader
RUNTIME DESTINATION
  bin
)
install(
PROGRAMS
  preprocess_logger.pl
DESTINATION
  bin
)

 
# Install header files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/dm_logger.h
DESTINATION
  include/${DM_LOGGER_NAME}/
)

# Install vapi files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${DM_LOGGER_NAME}.vapi
DESTINATION
  ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/
)

# Install pkg-config file...
install( FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${DM_LOGGER_NAME}.pc
DESTINATION
  ${CMAKE_INSTALL_LIBDIR}/pkgconfig
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

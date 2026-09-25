/*
 * Per-thread timestamp cache backing DMLogger.format_log_timestamp()
 * in dm_logger.vala.
 *
 * Implemented entirely in C because Vala has no native syntax for the
 * __thread storage-class specifier, and older valac (0.40, used for the
 * MinGW builds) neither includes cheader_filename headers for private
 * externs nor leaves their declarations alone: it emits its own plain
 * (non-TLS) "extern" declarations for variables, which fail to link
 * against MinGW's emulated TLS, and its own prototypes for functions,
 * which clash with <time.h>'s localtime_r/strftime. So Vala only ever
 * sees the single function below; its signature uses GLib types so it
 * matches the prototype valac emits for the Vala-side extern exactly.
 *
 * __thread is supported by GCC, Clang and MinGW-w64 -- the only
 * toolchains this library is built with.
 */
#ifndef DM_LOGGER_TLS_H
#define DM_LOGGER_TLS_H

#include <glib.h>

G_BEGIN_DECLS

/* Writes tstamp_usec (microseconds since the UNIX epoch) as local time
 * "YYYY-MM-DD HH:MM:SS" plus NUL into buf, which must hold >= 20 bytes.
 * The formatted prefix is cached per thread for the current second. */
void _dm_logger_format_timestamp_cached (gint64 tstamp_usec, gchar* buf);

G_END_DECLS

#endif /* DM_LOGGER_TLS_H */

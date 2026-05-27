/*
 * Thread-local storage backing the per-second timestamp cache in
 * dm_logger.vala. Defined in C because Vala has no native syntax for
 * the __thread storage-class specifier, and attaching it via a
 * [CCode (cname = "__thread ...")] hack collides with the type that
 * Vala still emits in front of the cname.
 *
 * One copy of these variables exists per thread, so concurrent
 * callers of DMLogger.format_log_timestamp() in not-threaded mode can
 * never tear each other's cache. __thread zero-initialises, so the
 * _valid flag starts out false and the first call in each thread
 * always runs strftime.
 *
 * Supported by GCC, Clang and MinGW-w64 -- the only toolchains this
 * library is built with.
 */
#ifndef DM_LOGGER_TLS_H
#define DM_LOGGER_TLS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

extern __thread int64_t _dm_logger_ts_cached_seconds;
extern __thread char    _dm_logger_ts_cached_prefix[20];
extern __thread bool    _dm_logger_ts_cached_valid;

#ifdef __cplusplus
}
#endif

#endif /* DM_LOGGER_TLS_H */

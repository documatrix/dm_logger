/* Per-thread timestamp cache backing DMLogger.format_log_timestamp().
 * See dm_logger_tls.h for rationale. */
#include "dm_logger_tls.h"

#include <string.h>
#include <time.h>

/* One copy per thread, so concurrent callers (not-threaded mode) never
 * tear each other's cache. __thread zero-initialises, so the _valid
 * flag starts out false and the first call in each thread always runs
 * strftime. Kept static: only this file ever touches them. */
static __thread gint64   ts_cached_seconds = 0;
static __thread gchar    ts_cached_prefix[20] = { 0 };
static __thread gboolean ts_cached_valid = FALSE;

/* "????-??-?? ??:??:??" -- the '?' are escaped so no "??-" trigraph forms. */
static const gchar ts_placeholder[20] = "\?\?\?\?-\?\?-\?\? \?\?:\?\?:\?\?";

/* Formats `seconds` into ts_cached_prefix. Returns FALSE if the time
 * could not be converted and a placeholder was written instead. */
static gboolean format_prefix (gint64 seconds)
{
  time_t t = (time_t) seconds;
  struct tm tm_local;

#ifdef _WIN32
  /* MinGW only exposes localtime_r as an inline shim around localtime_s
   * behind _POSIX_THREAD_SAFE_FUNCTIONS, so call localtime_s directly. */
  if (localtime_s (&tm_local, &t) != 0)
#else
  if (localtime_r (&t, &tm_local) == NULL)
#endif
  {
    /* Only happens for absurd time_t values on 32-bit builds. */
    memcpy (ts_cached_prefix, ts_placeholder, 20);
    return FALSE;
  }

  if (strftime (ts_cached_prefix, 20, "%Y-%m-%d %H:%M:%S", &tm_local) == 0)
  {
    /* strftime ran out of room (impossible with our 20-byte buffer for
     * this format, but be safe). */
    memcpy (ts_cached_prefix, ts_placeholder, 20);
  }
  return TRUE;
}

void _dm_logger_format_timestamp_cached (gint64 tstamp_usec, gchar* buf)
{
  gint64 seconds = tstamp_usec / 1000000;

  if (!ts_cached_valid || seconds != ts_cached_seconds)
  {
    /* A placeholder written for an unconvertible time is not cached,
     * so the next call retries. */
    ts_cached_valid = format_prefix (seconds);
    ts_cached_seconds = seconds;
  }

  memcpy (buf, ts_cached_prefix, 20);
}

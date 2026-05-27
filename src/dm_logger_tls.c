/* Definitions for the TLS variables declared in dm_logger_tls.h.
 * See that header for rationale. */
#include "dm_logger_tls.h"

__thread int64_t _dm_logger_ts_cached_seconds = 0;
__thread char    _dm_logger_ts_cached_prefix[20] = { 0 };
__thread bool    _dm_logger_ts_cached_valid = false;

/* Custom maxminddb_config.h for Swift package */
#ifndef MAXMINDDB_CONFIG_H
#define MAXMINDDB_CONFIG_H

#include <stdlib.h>

/* Define version information */
#define PACKAGE_VERSION "1.12.2"
#define PACKAGE_STRING "libmaxminddb 1.12.2"
#define PACKAGE_NAME "libmaxminddb"

/* Platform specific definitions */
#if defined(__APPLE__)
#define MMDB_UINT128_IS_BYTE_ARRAY 0
#elif defined(_WIN32)
#define MMDB_UINT128_IS_BYTE_ARRAY 1
#else
#define MMDB_UINT128_IS_BYTE_ARRAY 0
#endif

#endif /* MAXMINDDB_CONFIG_H */

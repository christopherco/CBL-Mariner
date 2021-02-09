/*
 * Copyright 2002-2019 The OpenSSL Project Authors. All Rights Reserved.
 * Copyright (c) 2002, Oracle and/or its affiliates. All rights reserved
 *
 * Licensed under the OpenSSL license (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#include <string.h>
#include "ec_local.h"
#include <openssl/err.h>
#include <openssl/obj_mac.h>
#include <openssl/opensslconf.h>
#include "internal/nelem.h"

typedef struct {
    int field_type,             /* either NID_X9_62_prime_field or
                                 * NID_X9_62_characteristic_two_field */
     seed_len, param_len;
    unsigned int cofactor;      /* promoted to BN_ULONG */
} EC_CURVE_DATA;

/* the nist prime curves */
static const struct {
    EC_CURVE_DATA h;
    unsigned char data[20 + 28 * 6];
} _EC_NIST_PRIME_224 = {
    {
        NID_X9_62_prime_field, 20, 28, 1
    },
    {
        /* seed */
        0xBD, 0x71, 0x34, 0x47, 0x99, 0xD5, 0xC7, 0xFC, 0xDC, 0x45, 0xB5, 0x9F,
        0xA3, 0xB9, 0xAB, 0x8F, 0x6A, 0x94, 0x8B, 0xC5,
        /* p */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01,
        /* a */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFE,
        /* b */
        0xB4, 0x05, 0x0A, 0x85, 0x0C, 0x04, 0xB3, 0xAB, 0xF5, 0x41, 0x32, 0x56,
        0x50, 0x44, 0xB0, 0xB7, 0xD7, 0xBF, 0xD8, 0xBA, 0x27, 0x0B, 0x39, 0x43,
        0x23, 0x55, 0xFF, 0xB4,
        /* x */
        0xB7, 0x0E, 0x0C, 0xBD, 0x6B, 0xB4, 0xBF, 0x7F, 0x32, 0x13, 0x90, 0xB9,
        0x4A, 0x03, 0xC1, 0xD3, 0x56, 0xC2, 0x11, 0x22, 0x34, 0x32, 0x80, 0xD6,
        0x11, 0x5C, 0x1D, 0x21,
        /* y */
        0xbd, 0x37, 0x63, 0x88, 0xb5, 0xf7, 0x23, 0xfb, 0x4c, 0x22, 0xdf, 0xe6,
        0xcd, 0x43, 0x75, 0xa0, 0x5a, 0x07, 0x47, 0x64, 0x44, 0xd5, 0x81, 0x99,
        0x85, 0x00, 0x7e, 0x34,
        /* order */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0x16, 0xA2, 0xE0, 0xB8, 0xF0, 0x3E, 0x13, 0xDD, 0x29, 0x45,
        0x5C, 0x5C, 0x2A, 0x3D
    }
};

static const struct {
    EC_CURVE_DATA h;
    unsigned char data[20 + 48 * 6];
} _EC_NIST_PRIME_384 = {
    {
        NID_X9_62_prime_field, 20, 48, 1
    },
    {
        /* seed */
        0xA3, 0x35, 0x92, 0x6A, 0xA3, 0x19, 0xA2, 0x7A, 0x1D, 0x00, 0x89, 0x6A,
        0x67, 0x73, 0xA4, 0x82, 0x7A, 0xCD, 0xAC, 0x73,
        /* p */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF,
        /* a */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFC,
        /* b */
        0xB3, 0x31, 0x2F, 0xA7, 0xE2, 0x3E, 0xE7, 0xE4, 0x98, 0x8E, 0x05, 0x6B,
        0xE3, 0xF8, 0x2D, 0x19, 0x18, 0x1D, 0x9C, 0x6E, 0xFE, 0x81, 0x41, 0x12,
        0x03, 0x14, 0x08, 0x8F, 0x50, 0x13, 0x87, 0x5A, 0xC6, 0x56, 0x39, 0x8D,
        0x8A, 0x2E, 0xD1, 0x9D, 0x2A, 0x85, 0xC8, 0xED, 0xD3, 0xEC, 0x2A, 0xEF,
        /* x */
        0xAA, 0x87, 0xCA, 0x22, 0xBE, 0x8B, 0x05, 0x37, 0x8E, 0xB1, 0xC7, 0x1E,
        0xF3, 0x20, 0xAD, 0x74, 0x6E, 0x1D, 0x3B, 0x62, 0x8B, 0xA7, 0x9B, 0x98,
        0x59, 0xF7, 0x41, 0xE0, 0x82, 0x54, 0x2A, 0x38, 0x55, 0x02, 0xF2, 0x5D,
        0xBF, 0x55, 0x29, 0x6C, 0x3A, 0x54, 0x5E, 0x38, 0x72, 0x76, 0x0A, 0xB7,
        /* y */
        0x36, 0x17, 0xde, 0x4a, 0x96, 0x26, 0x2c, 0x6f, 0x5d, 0x9e, 0x98, 0xbf,
        0x92, 0x92, 0xdc, 0x29, 0xf8, 0xf4, 0x1d, 0xbd, 0x28, 0x9a, 0x14, 0x7c,
        0xe9, 0xda, 0x31, 0x13, 0xb5, 0xf0, 0xb8, 0xc0, 0x0a, 0x60, 0xb1, 0xce,
        0x1d, 0x7e, 0x81, 0x9d, 0x7a, 0x43, 0x1d, 0x7c, 0x90, 0xea, 0x0e, 0x5f,
        /* order */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xC7, 0x63, 0x4D, 0x81, 0xF4, 0x37, 0x2D, 0xDF, 0x58, 0x1A, 0x0D, 0xB2,
        0x48, 0xB0, 0xA7, 0x7A, 0xEC, 0xEC, 0x19, 0x6A, 0xCC, 0xC5, 0x29, 0x73
    }
};

static const struct {
    EC_CURVE_DATA h;
    unsigned char data[20 + 66 * 6];
} _EC_NIST_PRIME_521 = {
    {
        NID_X9_62_prime_field, 20, 66, 1
    },
    {
        /* seed */
        0xD0, 0x9E, 0x88, 0x00, 0x29, 0x1C, 0xB8, 0x53, 0x96, 0xCC, 0x67, 0x17,
        0x39, 0x32, 0x84, 0xAA, 0xA0, 0xDA, 0x64, 0xBA,
        /* p */
        0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        /* a */
        0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFC,
        /* b */
        0x00, 0x51, 0x95, 0x3E, 0xB9, 0x61, 0x8E, 0x1C, 0x9A, 0x1F, 0x92, 0x9A,
        0x21, 0xA0, 0xB6, 0x85, 0x40, 0xEE, 0xA2, 0xDA, 0x72, 0x5B, 0x99, 0xB3,
        0x15, 0xF3, 0xB8, 0xB4, 0x89, 0x91, 0x8E, 0xF1, 0x09, 0xE1, 0x56, 0x19,
        0x39, 0x51, 0xEC, 0x7E, 0x93, 0x7B, 0x16, 0x52, 0xC0, 0xBD, 0x3B, 0xB1,
        0xBF, 0x07, 0x35, 0x73, 0xDF, 0x88, 0x3D, 0x2C, 0x34, 0xF1, 0xEF, 0x45,
        0x1F, 0xD4, 0x6B, 0x50, 0x3F, 0x00,
        /* x */
        0x00, 0xC6, 0x85, 0x8E, 0x06, 0xB7, 0x04, 0x04, 0xE9, 0xCD, 0x9E, 0x3E,
        0xCB, 0x66, 0x23, 0x95, 0xB4, 0x42, 0x9C, 0x64, 0x81, 0x39, 0x05, 0x3F,
        0xB5, 0x21, 0xF8, 0x28, 0xAF, 0x60, 0x6B, 0x4D, 0x3D, 0xBA, 0xA1, 0x4B,
        0x5E, 0x77, 0xEF, 0xE7, 0x59, 0x28, 0xFE, 0x1D, 0xC1, 0x27, 0xA2, 0xFF,
        0xA8, 0xDE, 0x33, 0x48, 0xB3, 0xC1, 0x85, 0x6A, 0x42, 0x9B, 0xF9, 0x7E,
        0x7E, 0x31, 0xC2, 0xE5, 0xBD, 0x66,
        /* y */
        0x01, 0x18, 0x39, 0x29, 0x6a, 0x78, 0x9a, 0x3b, 0xc0, 0x04, 0x5c, 0x8a,
        0x5f, 0xb4, 0x2c, 0x7d, 0x1b, 0xd9, 0x98, 0xf5, 0x44, 0x49, 0x57, 0x9b,
        0x44, 0x68, 0x17, 0xaf, 0xbd, 0x17, 0x27, 0x3e, 0x66, 0x2c, 0x97, 0xee,
        0x72, 0x99, 0x5e, 0xf4, 0x26, 0x40, 0xc5, 0x50, 0xb9, 0x01, 0x3f, 0xad,
        0x07, 0x61, 0x35, 0x3c, 0x70, 0x86, 0xa2, 0x72, 0xc2, 0x40, 0x88, 0xbe,
        0x94, 0x76, 0x9f, 0xd1, 0x66, 0x50,
        /* order */
        0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFA, 0x51, 0x86,
        0x87, 0x83, 0xBF, 0x2F, 0x96, 0x6B, 0x7F, 0xCC, 0x01, 0x48, 0xF7, 0x09,
        0xA5, 0xD0, 0x3B, 0xB5, 0xC9, 0xB8, 0x89, 0x9C, 0x47, 0xAE, 0xBB, 0x6F,
        0xB7, 0x1E, 0x91, 0x38, 0x64, 0x09
    }
};

static const struct {
    EC_CURVE_DATA h;
    unsigned char data[20 + 32 * 6];
} _EC_X9_62_PRIME_256V1 = {
    {
        NID_X9_62_prime_field, 20, 32, 1
    },
    {
        /* seed */
        0xC4, 0x9D, 0x36, 0x08, 0x86, 0xE7, 0x04, 0x93, 0x6A, 0x66, 0x78, 0xE1,
        0x13, 0x9D, 0x26, 0xB7, 0x81, 0x9F, 0x7E, 0x90,
        /* p */
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        /* a */
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFC,
        /* b */
        0x5A, 0xC6, 0x35, 0xD8, 0xAA, 0x3A, 0x93, 0xE7, 0xB3, 0xEB, 0xBD, 0x55,
        0x76, 0x98, 0x86, 0xBC, 0x65, 0x1D, 0x06, 0xB0, 0xCC, 0x53, 0xB0, 0xF6,
        0x3B, 0xCE, 0x3C, 0x3E, 0x27, 0xD2, 0x60, 0x4B,
        /* x */
        0x6B, 0x17, 0xD1, 0xF2, 0xE1, 0x2C, 0x42, 0x47, 0xF8, 0xBC, 0xE6, 0xE5,
        0x63, 0xA4, 0x40, 0xF2, 0x77, 0x03, 0x7D, 0x81, 0x2D, 0xEB, 0x33, 0xA0,
        0xF4, 0xA1, 0x39, 0x45, 0xD8, 0x98, 0xC2, 0x96,
        /* y */
        0x4f, 0xe3, 0x42, 0xe2, 0xfe, 0x1a, 0x7f, 0x9b, 0x8e, 0xe7, 0xeb, 0x4a,
        0x7c, 0x0f, 0x9e, 0x16, 0x2b, 0xce, 0x33, 0x57, 0x6b, 0x31, 0x5e, 0xce,
        0xcb, 0xb6, 0x40, 0x68, 0x37, 0xbf, 0x51, 0xf5,
        /* order */
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84,
        0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51
    }
};

static const struct {
    EC_CURVE_DATA h;
    unsigned char data[0 + 32 * 6];
} _EC_SECG_PRIME_256K1 = {
    {
        NID_X9_62_prime_field, 0, 32, 1
    },
    {
        /* no seed */
        /* p */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFC, 0x2F,
        /* a */
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        /* b */
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07,
        /* x */
        0x79, 0xBE, 0x66, 0x7E, 0xF9, 0xDC, 0xBB, 0xAC, 0x55, 0xA0, 0x62, 0x95,
        0xCE, 0x87, 0x0B, 0x07, 0x02, 0x9B, 0xFC, 0xDB, 0x2D, 0xCE, 0x28, 0xD9,
        0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98,
        /* y */
        0x48, 0x3a, 0xda, 0x77, 0x26, 0xa3, 0xc4, 0x65, 0x5d, 0xa4, 0xfb, 0xfc,
        0x0e, 0x11, 0x08, 0xa8, 0xfd, 0x17, 0xb4, 0x48, 0xa6, 0x85, 0x54, 0x19,
        0x9c, 0x47, 0xd0, 0x8f, 0xfb, 0x10, 0xd4, 0xb8,
        /* order */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFE, 0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
        0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
    }
};

typedef struct _ec_list_element_st {
    int nid;
    const EC_CURVE_DATA *data;
    const EC_METHOD *(*meth) (void);
    const char *comment;
} ec_list_element;

static const ec_list_element curve_list[] = {
    /* prime field curves */
    /* secg curves */
#ifndef OPENSSL_NO_EC_NISTP_64_GCC_128
    {NID_secp224r1, &_EC_NIST_PRIME_224.h, EC_GFp_nistp224_method,
     "NIST/SECG curve over a 224 bit prime field"},
#else
    {NID_secp224r1, &_EC_NIST_PRIME_224.h, 0,
     "NIST/SECG curve over a 224 bit prime field"},
#endif
    {NID_secp256k1, &_EC_SECG_PRIME_256K1.h, 0,
     "SECG curve over a 256 bit prime field"},
    /* SECG secp256r1 is the same as X9.62 prime256v1 and hence omitted */
    {NID_secp384r1, &_EC_NIST_PRIME_384.h, 0,
     "NIST/SECG curve over a 384 bit prime field"},
#ifndef OPENSSL_NO_EC_NISTP_64_GCC_128
    {NID_secp521r1, &_EC_NIST_PRIME_521.h, EC_GFp_nistp521_method,
     "NIST/SECG curve over a 521 bit prime field"},
#else
    {NID_secp521r1, &_EC_NIST_PRIME_521.h, 0,
     "NIST/SECG curve over a 521 bit prime field"},
#endif
    /* X9.62 curves */
    {NID_X9_62_prime256v1, &_EC_X9_62_PRIME_256V1.h,
#if defined(ECP_NISTZ256_ASM)
     EC_GFp_nistz256_method,
#elif !defined(OPENSSL_NO_EC_NISTP_64_GCC_128)
     EC_GFp_nistp256_method,
#else
     0,
#endif
     "X9.62/SECG curve over a 256 bit prime field"},
};

#define curve_list_length OSSL_NELEM(curve_list)

static EC_GROUP *ec_group_new_from_data(const ec_list_element curve)
{
    EC_GROUP *group = NULL;
    EC_POINT *P = NULL;
    BN_CTX *ctx = NULL;
    BIGNUM *p = NULL, *a = NULL, *b = NULL, *x = NULL, *y = NULL, *order =
        NULL;
    int ok = 0;
    int seed_len, param_len;
    const EC_METHOD *meth;
    const EC_CURVE_DATA *data;
    const unsigned char *params;

    /* If no curve data curve method must handle everything */
    if (curve.data == NULL)
        return EC_GROUP_new(curve.meth != NULL ? curve.meth() : NULL);

    if ((ctx = BN_CTX_new()) == NULL) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_MALLOC_FAILURE);
        goto err;
    }

    data = curve.data;
    seed_len = data->seed_len;
    param_len = data->param_len;
    params = (const unsigned char *)(data + 1); /* skip header */
    params += seed_len;         /* skip seed */

    if ((p = BN_bin2bn(params + 0 * param_len, param_len, NULL)) == NULL
        || (a = BN_bin2bn(params + 1 * param_len, param_len, NULL)) == NULL
        || (b = BN_bin2bn(params + 2 * param_len, param_len, NULL)) == NULL) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_BN_LIB);
        goto err;
    }

    if (curve.meth != 0) {
        meth = curve.meth();
        if (((group = EC_GROUP_new(meth)) == NULL) ||
            (!(group->meth->group_set_curve(group, p, a, b, ctx)))) {
            ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
            goto err;
        }
    } else if (data->field_type == NID_X9_62_prime_field) {
        if ((group = EC_GROUP_new_curve_GFp(p, a, b, ctx)) == NULL) {
            ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
            goto err;
        }
    }
#ifndef OPENSSL_NO_EC2M
    else {                      /* field_type ==
                                 * NID_X9_62_characteristic_two_field */

        if ((group = EC_GROUP_new_curve_GF2m(p, a, b, ctx)) == NULL) {
            ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
            goto err;
        }
    }
#endif

    EC_GROUP_set_curve_name(group, curve.nid);

    if ((P = EC_POINT_new(group)) == NULL) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
        goto err;
    }

    if ((x = BN_bin2bn(params + 3 * param_len, param_len, NULL)) == NULL
        || (y = BN_bin2bn(params + 4 * param_len, param_len, NULL)) == NULL) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_BN_LIB);
        goto err;
    }
    if (!EC_POINT_set_affine_coordinates(group, P, x, y, ctx)) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
        goto err;
    }
    if ((order = BN_bin2bn(params + 5 * param_len, param_len, NULL)) == NULL
        || !BN_set_word(x, (BN_ULONG)data->cofactor)) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_BN_LIB);
        goto err;
    }
    if (!EC_GROUP_set_generator(group, P, order, x)) {
        ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
        goto err;
    }
    if (seed_len) {
        if (!EC_GROUP_set_seed(group, params - seed_len, seed_len)) {
            ECerr(EC_F_EC_GROUP_NEW_FROM_DATA, ERR_R_EC_LIB);
            goto err;
        }
    }
    ok = 1;
 err:
    if (!ok) {
        EC_GROUP_free(group);
        group = NULL;
    }
    EC_POINT_free(P);
    BN_CTX_free(ctx);
    BN_free(p);
    BN_free(a);
    BN_free(b);
    BN_free(order);
    BN_free(x);
    BN_free(y);
    return group;
}

EC_GROUP *EC_GROUP_new_by_curve_name(int nid)
{
    size_t i;
    EC_GROUP *ret = NULL;

    if (nid <= 0)
        return NULL;

    for (i = 0; i < curve_list_length; i++)
        if (curve_list[i].nid == nid) {
            ret = ec_group_new_from_data(curve_list[i]);
            break;
        }

    if (ret == NULL) {
        ECerr(EC_F_EC_GROUP_NEW_BY_CURVE_NAME, EC_R_UNKNOWN_GROUP);
        return NULL;
    }

    return ret;
}

size_t EC_get_builtin_curves(EC_builtin_curve *r, size_t nitems)
{
    size_t i, min;

    if (r == NULL || nitems == 0)
        return curve_list_length;

    min = nitems < curve_list_length ? nitems : curve_list_length;

    for (i = 0; i < min; i++) {
        r[i].nid = curve_list[i].nid;
        r[i].comment = curve_list[i].comment;
    }

    return curve_list_length;
}

/* Functions to translate between common NIST curve names and NIDs */

typedef struct {
    const char *name;           /* NIST Name of curve */
    int nid;                    /* Curve NID */
} EC_NIST_NAME;

static EC_NIST_NAME nist_curves[] = {
    {"B-163", NID_sect163r2},
    {"B-233", NID_sect233r1},
    {"B-283", NID_sect283r1},
    {"B-409", NID_sect409r1},
    {"B-571", NID_sect571r1},
    {"K-163", NID_sect163k1},
    {"K-233", NID_sect233k1},
    {"K-283", NID_sect283k1},
    {"K-409", NID_sect409k1},
    {"K-571", NID_sect571k1},
    {"P-192", NID_X9_62_prime192v1},
    {"P-224", NID_secp224r1},
    {"P-256", NID_X9_62_prime256v1},
    {"P-384", NID_secp384r1},
    {"P-521", NID_secp521r1}
};

const char *EC_curve_nid2nist(int nid)
{
    size_t i;
    for (i = 0; i < OSSL_NELEM(nist_curves); i++) {
        if (nist_curves[i].nid == nid)
            return nist_curves[i].name;
    }
    return NULL;
}

int EC_curve_nist2nid(const char *name)
{
    size_t i;
    for (i = 0; i < OSSL_NELEM(nist_curves); i++) {
        if (strcmp(nist_curves[i].name, name) == 0)
            return nist_curves[i].nid;
    }
    return NID_undef;
}

#define NUM_BN_FIELDS 6
/*
 * Validates EC domain parameter data for known named curves.
 * This can be used when a curve is loaded explicitly (without a curve
 * name) or to validate that domain parameters have not been modified.
 *
 * Returns: The nid associated with the found named curve, or NID_undef
 *          if not found. If there was an error it returns -1.
 */
int ec_curve_nid_from_params(const EC_GROUP *group, BN_CTX *ctx)
{
    int ret = -1, nid, len, field_type, param_len;
    size_t i, seed_len;
    const unsigned char *seed, *params_seed, *params;
    unsigned char *param_bytes = NULL;
    const EC_CURVE_DATA *data;
    const EC_POINT *generator = NULL;
    const EC_METHOD *meth;
    const BIGNUM *cofactor = NULL;
    /* An array of BIGNUMs for (p, a, b, x, y, order) */
    BIGNUM *bn[NUM_BN_FIELDS] = {NULL, NULL, NULL, NULL, NULL, NULL};

    meth = EC_GROUP_method_of(group);
    if (meth == NULL)
        return -1;
    /* Use the optional named curve nid as a search field */
    nid = EC_GROUP_get_curve_name(group);
    field_type = EC_METHOD_get_field_type(meth);
    seed_len = EC_GROUP_get_seed_len(group);
    seed = EC_GROUP_get0_seed(group);
    cofactor = EC_GROUP_get0_cofactor(group);

    BN_CTX_start(ctx);

    /*
     * The built-in curves contains data fields (p, a, b, x, y, order) that are
     * all zero-padded to be the same size. The size of the padding is
     * determined by either the number of bytes in the field modulus (p) or the
     * EC group order, whichever is larger.
     */
    param_len = BN_num_bytes(group->order);
    len = BN_num_bytes(group->field);
    if (len > param_len)
        param_len = len;

    /* Allocate space to store the padded data for (p, a, b, x, y, order)  */
    param_bytes = OPENSSL_malloc(param_len * NUM_BN_FIELDS);
    if (param_bytes == NULL)
        goto end;

    /* Create the bignums */
    for (i = 0; i < NUM_BN_FIELDS; ++i) {
        if ((bn[i] = BN_CTX_get(ctx)) == NULL)
            goto end;
    }
    /*
     * Fill in the bn array with the same values as the internal curves
     * i.e. the values are p, a, b, x, y, order.
     */
    /* Get p, a & b */
    if (!(EC_GROUP_get_curve(group, bn[0], bn[1], bn[2], ctx)
        && ((generator = EC_GROUP_get0_generator(group)) != NULL)
        /* Get x & y */
        && EC_POINT_get_affine_coordinates(group, generator, bn[3], bn[4], ctx)
        /* Get order */
        && EC_GROUP_get_order(group, bn[5], ctx)))
        goto end;

   /*
     * Convert the bignum array to bytes that are joined together to form
     * a single buffer that contains data for all fields.
     * (p, a, b, x, y, order) are all zero padded to be the same size.
     */
    for (i = 0; i < NUM_BN_FIELDS; ++i) {
        if (BN_bn2binpad(bn[i], &param_bytes[i*param_len], param_len) <= 0)
            goto end;
    }

    for (i = 0; i < curve_list_length; i++) {
        const ec_list_element curve = curve_list[i];

        data = curve.data;
        /* Get the raw order byte data */
        params_seed = (const unsigned char *)(data + 1); /* skip header */
        params = params_seed + data->seed_len;

        /* Look for unique fields in the fixed curve data */
        if (data->field_type == field_type
            && param_len == data->param_len
            && (nid <= 0 || nid == curve.nid)
            /* check the optional cofactor (ignore if its zero) */
            && (BN_is_zero(cofactor)
                || BN_is_word(cofactor, (const BN_ULONG)curve.data->cofactor))
            /* Check the optional seed (ignore if its not set) */
            && (data->seed_len == 0 || seed_len == 0
                || ((size_t)data->seed_len == seed_len
                     && memcmp(params_seed, seed, seed_len) == 0))
            /* Check that the groups params match the built-in curve params */
            && memcmp(param_bytes, params, param_len * NUM_BN_FIELDS)
                             == 0) {
            ret = curve.nid;
            goto end;
        }
    }
    /* Gets here if the group was not found */
    ret = NID_undef;
end:
    OPENSSL_free(param_bytes);
    BN_CTX_end(ctx);
    return ret;
}

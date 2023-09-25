// =============================================================================
//  Program : string.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/09/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the minimal string library for aquila.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
#include <stdio.h>
#include <string.h>

void *memcpy(void *d, void *s, size_t n)
{
    unsigned char *dst = (unsigned char *) d;
    unsigned char *src = (unsigned char *) s;

    for (int idx = 0; idx < n; idx++) *(dst++) = *(src++);
    return d;
}

void *memmove(void *d, void *s, size_t n)
{
    unsigned char *dst = (unsigned char *) d;
    unsigned char *src = (unsigned char *) s;

    if ((unsigned) d >= (unsigned) s &&
        (unsigned) d <= (unsigned) s + n)
    {
        for (int idx = n - 1; idx >= 0; idx--) dst[idx] = src[idx];
    }
    else
    {
        for (int idx = 0; idx < n; idx++) *(dst++) = *(src++);
    }

    return d;
}

void *memset(void *d, int v, size_t n)
{
    unsigned char *dst = (unsigned char *) d;

    for (int idx = 0; idx < n; idx++) *(dst++) = (unsigned char) v;
    return d;
}

long strlen(char *s)
{
    long n = 0;

    while (*s++) n++;
    return n;
}

/* original strcpy */
/*
char *strcpy(char *dst, char *src)
{
    char *tmp = dst;

    while (*src) *(tmp++) = *(src++);
    *tmp = 0;
    return dst;
}
*/

/* edited strcpy from Newlib */
// ------------------------------------------------------------
#define UNALIGNED(X, Y) (((long)X & (sizeof (long) - 1)) | ((long)Y & (sizeof (long) - 1)))
#define DETECTNULL(X) (((X)-0x01010101) & ~(X) & 0x80808080)

char *strcpy(char *dst, char *src)
{
    
    const char *tmp_src = src;
    char *tmp_dst = dst;
    const long *aligned_src = (long *) src; 
    long *aligned_dst;
    
    if(!UNALIGNED(src,dst))
    {
        aligned_dst = (long *) dst;
        aligned_src = (long *) src;

        while(!DETECTNULL(*aligned_src))
        {
            *(aligned_dst++) = *(aligned_src++);
        }

        tmp_src = (char *) aligned_src;
        tmp_dst = (char *) aligned_dst;
    }
    
    // also assign null value
    while((*(tmp_dst++) = *(tmp_src++)));

    return dst;
}

char *strncpy(char *dst, char *src, size_t n)
{
    char *tmp = dst;

    while (*src && n) *(tmp++) = *(src++), n--;
    while (n--) *(tmp++) = 0;
    return dst;
}

char *strcat(char *dst, char *src)
{
    char *tmp = dst;

    while (*tmp) tmp++;
    while (*src) *(tmp++) = *(src++);
    *tmp = 0;
    return dst;
}

char *strncat(char *dst, char *src, size_t n)
{
    char *tmp = dst;

    while (*tmp) tmp++;
    while (*src && n) *(tmp++) = *(src++), n--;
    *tmp = 0;
    return dst;
}

/* original strcmp */
/*
int  strcmp(char *s1, char *s2)
{
    int value;
 
    s1--, s2--;
    do
    {
        s1++, s2++;
        if (*s1 == *s2)
        {
            value = 0;
        }
        else if (*s1 < *s2)
        {
            value = -1;
            break;
        }
        else
        {
            value = 1;
            break;
        }
    } while (*s1 != 0 && *s2 != 0);
    return value;
}
*/

/* edited strcmp from Newlib*/
int  strcmp(char *s1, char *s2)
{
    const unsigned long *a1, *a2;

    if(!UNALIGNED(s1,s2))
    {
        a1 = (unsigned long *) s1;
        a2 = (unsigned long *) s2;
        while(*a1 == *a2)
        {
            if(DETECTNULL(*a1)) return 0;

            a1++;
            a2++;
        }

        s1 = (char *)a1;
        s2 = (char *)a2;
    }

    while(*s1 != '\0' && *s1 == *s2)
    {
        s1++;
        s2++;
    }

    return *(unsigned char *)s1 - *(unsigned char *)s2;
}


int  strncmp(char *s1, char *s2, size_t n)
{
    int value;

    s1--, s2--;
    do
    {
        s1++, s2++;
        if (*s1 == *s2)
        {
            value = 0;
        }
        else if (*s1 < *s2)
        {
            value = -1;
            break;
        }
        else
        {
            value = 1;
            break;
        }
    } while (--n && *s1 != 0 && *s2 != 0);
    return value;
}

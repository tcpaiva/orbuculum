/*
 * This module is derrived from;
 *
 *  iceprog -- simple programming tool for FTDI-based Lattice iCE programmers
 *
 *  Copyright (C) 2015  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  Relevant Documents:
 *  -------------------
 *  http://www.latticesemi.com/~/media/Documents/UserManuals/EI/icestickusermanual.pdf
 *  http://www.micron.com/~/media/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf
 *  http://www.ftdichip.com/Support/Documents/AppNotes/AN_108_Command_Processor_for_MPSSE_and_MCU_Host_Bus_Emulation_Modes.pdf
 */

#define _GNU_SOURCE

#include <libftdi1/ftdi.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <getopt.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "iceproglite.h"
#include "generics.h"

static struct ftdi_context ftdic;
static unsigned char ftdi_latency;

// ====================================================================================================
static uint8_t _recv_byte()
{
    uint8_t data;

    while ( 1 )
    {
        int rc = ftdi_read_data( &ftdic, &data, 1 );

        if ( rc < 0 )
        {
            genericsReport( V_ERROR, "Read error.\n" );
        }

        if ( rc == 1 )
        {
            break;
        }

        usleep( 100 );
    }

    return data;
}
// ====================================================================================================
static void _send_byte( uint8_t data )
{
    int rc = ftdi_write_data( &ftdic, &data, 1 );

    if ( rc != 1 )
    {
        genericsReport( V_ERROR, "Write error (single byte, rc=%d, expected %d).\n", rc, 1 );
    }
}
// ====================================================================================================
static void _send_spi( uint8_t *data, int n )
{
    if ( n < 1 )
    {
        return;
    }

    _send_byte( 0x11 );
    _send_byte( n - 1 );
    _send_byte( ( n - 1 ) >> 8 );

    int rc = ftdi_write_data( &ftdic, data, n );

    if ( rc != n )
    {
        genericsReport( V_ERROR, "Write error (chunk, rc=%d, expected %d).\n", rc, n );
    }
}
// ====================================================================================================
static void _set_gpio( int slavesel_b, int creset_b )
{
    uint8_t gpio = 1;

    if ( slavesel_b )
    {
        // ADBUS4 (GPIOL0)
        gpio |= 0x10;
    }

    if ( creset_b )
    {
        // ADBUS7 (GPIOL3)
        gpio |= 0x80;
    }

    _send_byte( 0x80 );
    _send_byte( gpio );
    _send_byte( 0x93 );
}
// ====================================================================================================
static int _get_cdone()
{
    uint8_t data;
    _send_byte( 0x81 );
    data = _recv_byte();
    // ADBUS6 (GPIOL2)
    return ( data & 0x40 ) != 0;
}
// ====================================================================================================
// ====================================================================================================
// ====================================================================================================
bool iceprogliteProgram( const char *filename, bool force, int vid, int pid, int ifnum )

{
    FILE *f;
    bool retVal = false;

    // ---------------------------------------------------------
    // Initialize USB connection to FT2232H
    // ---------------------------------------------------------

    genericsReport( V_INFO, "iceproglite init.." EOL );

    ftdi_init( &ftdic );
    ftdi_set_interface( &ftdic, ifnum );

    if ( ftdi_usb_open( &ftdic, vid, pid ) )
    {
        genericsReport( V_ERROR, "Can't find iCE FTDI USB device (%04X:%04X)." EOL, vid, pid );
    }
    else if ( ftdi_usb_reset( &ftdic ) )
    {
        genericsReport( V_ERROR, "Failed to reset iCE FTDI USB device." EOL );
    }
    else if ( ftdi_usb_purge_buffers( &ftdic ) )
    {
        genericsReport( V_ERROR, "Failed to purge buffers on iCE FTDI USB device." EOL );
    }
    else if ( ftdi_get_latency_timer( &ftdic, &ftdi_latency ) < 0 )
    {
        genericsReport( V_ERROR, "Failed to get latency timer (%s)." EOL, ftdi_get_error_string( &ftdic ) );
    }
    else if ( ftdi_set_latency_timer( &ftdic, 1 ) < 0 )
    {
        genericsReport( V_ERROR, "Failed to set latency timer (%s)." EOL, ftdi_get_error_string( &ftdic ) );
    }
    else if ( ftdi_set_bitmode( &ftdic, 0xff, BITMODE_MPSSE ) < 0 )
    {
        genericsReport( V_ERROR, "Failed to set BITMODE_MPSSE on iCE FTDI USB device." EOL );
    }
    else
    {
        genericsReport( V_INFO, "Passed checks, start process" EOL );
        // enable clock divide by 5
        _send_byte( 0x8b );

        // set 6 MHz clock
        _send_byte( 0x86 );
        _send_byte( 0x00 );
        _send_byte( 0x00 );

        if ( ( _get_cdone() ) && ( !force ) )
        {
            retVal = true;
        }
        else
        {
            if ( ( f = fopen( filename, "rb" ) ) == NULL )
            {
                genericsReport( V_ERROR, "Can't open '%s' for reading" EOL, filename );
            }
            else
            {
                _set_gpio( 1, 1 );
                usleep( 100000 );

                // ---------------------------------------------------------
                // Reset
                // ---------------------------------------------------------

                genericsReport( V_INFO, "reset..\n" );

                _set_gpio( 0, 0 );
                usleep( 100 );

                _set_gpio( 0, 1 );
                usleep( 2000 );

                genericsReport( V_INFO, "cdone: %s" EOL, _get_cdone() ? "high" : "low" );

                // ---------------------------------------------------------
                // Program
                // ---------------------------------------------------------

                genericsReport( V_INFO, "programming..\n" );

                while ( 1 )
                {
                    static unsigned char buffer[4096];
                    int rc = fread( buffer, 1, 4096, f );

                    if ( rc <= 0 )
                    {
                        break;
                    }

                    _send_spi( buffer, rc );
                }

                // add 48 dummy bits
                _send_byte( 0x8f );
                _send_byte( 0x05 );
                _send_byte( 0x00 );

                // add 1 more dummy bit
                _send_byte( 0x8e );
                _send_byte( 0x00 );

                genericsReport( V_INFO, "cdone: %s" EOL, _get_cdone() ? "high" : "low" );

                fclose( f );
                retVal = true;
            }
        }
    }

    // ---------------------------------------------------------
    // Exit
    // ---------------------------------------------------------

    ftdi_set_latency_timer( &ftdic, ftdi_latency );
    ftdi_disable_bitbang( &ftdic );
    ftdi_usb_close( &ftdic );
    ftdi_deinit( &ftdic );
    return retVal;
}

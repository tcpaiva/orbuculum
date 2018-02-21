/*
 * This file is part of the Black Magic Debug project.
 *
 * Copyright (C) 2011  Black Sphere Technologies Ltd.
 * Written by Gareth McMullin <gareth@blacksphere.co.nz>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include "generics.h"
#include "general.h"
#include "gdb_if.h"
#include "version.h"

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <assert.h>
#include <unistd.h>
#include <sys/time.h>

void platform_init(void)

{
  gdb_if_init();
  genericsReport(V_INFO,"Blackmagic probe is running " EOL);
}

void platform_srst_set_val(bool assert)
{
	(void)assert;
	platform_buffer_flush();
}

bool platform_srst_get_val(void) { return false; }

void platform_buffer_flush(void)
{

}

int platform_buffer_write(const uint8_t *data, int size)

{
  return 0;
}

int platform_buffer_read(uint8_t *data, int size)
{
  return 0;
}

const char *platform_target_voltage(void)
{
	return "not supported";
}

void platform_delay(uint32_t ms)
{
	usleep(ms * 1000);
}

uint32_t platform_time_ms(void)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (tv.tv_sec * 1000) + (tv.tv_usec / 1000);
}

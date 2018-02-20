/*
 * This file is part of the Black Magic Debug project.
 *
 * Copyright (C) 2016  Black Sphere Technologies Ltd.
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
#include "swdptap.h"

bool fpgaDbgRead(uint32_t len, bool withParity, uint32_t *dataStore);
bool fpgaDbgWrite(uint32_t val, uint32_t len, bool withParity);

uint32_t swdptap_seq_in(int ticks)

{
  uint32_t r;
   fpgaDbgRead(ticks, false, &r);
   genericsReport(V_DEBUG,"SWD-In %d bits => %02x" EOL,ticks,(r));
   return r&((1<<(ticks+1))-1);
}

bool swdptap_seq_in_parity(uint32_t *r, int ticks)

{
  bool bad=fpgaDbgRead(ticks, true, r);
  genericsReport(V_DEBUG,"SWD-InP (%s) %d bits => %02x" EOL,bad?"Bad":"Good",ticks,*r);
  return bad;
}

void swdptap_seq_out(uint32_t MS, int ticks)

{
  fpgaDbgWrite(MS, ticks, false);
  genericsReport(V_DEBUG,"SWD-Out %d bits (%8x)" EOL,ticks,MS);	
}

void swdptap_seq_out_parity(uint32_t MS, int ticks)
{
  fpgaDbgWrite(MS, ticks, true);
  genericsReport(V_DEBUG,"SWD-OutP %d bits (%02x)" EOL,ticks,MS);		
}

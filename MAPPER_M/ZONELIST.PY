#!/usr/bin/env python

# zonelist.py: Dark Age of Camelot zone lister.
# See http://www.randomly.org/projects/mapper/ for updates and sample output.

# Copyright (c) 2002, Oliver Jowett <oliver@randomly.org>
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Updated: 2002/10/28

import os, ConfigParser
import dempak

def run(argv):
    gamepath = None
    selectregion = None
    simple = 0

    i = 1
    while i < len(argv):
        if argv[i] == '-gamepath':
            gamepath = argv[i+1]
            i += 2
        elif argv[i] == '-region':
            selectregion = int(argv[i+1])
            i += 2
        elif argv[i] == '-simple':
            simple = 1
            i += 1
        else:
            print "Unknown option:", argv[i]
            return 1

    if not gamepath:
        print "Usage: %s -gamepath <gamedir> [-region <regionID>] [-simple]" % argv[0]
        return 1
    
    cp = ConfigParser.ConfigParser()
    try:
        cp.readfp(dempak.getMPAKEntry(os.path.join(gamepath, 'zones', 'zones.mpk'), 'zones.dat'))
    except ConfigParser.ParsingError:
        # Ignore it -- the structure isn't quite what CP expects
        pass

    sections = cp.sections()
    sections.sort()
    for s in sections:
        if s[:4] == 'zone':
            id = int(s[4:])
            enabled = int(cp.get(s, 'enabled'))
            name = cp.get(s, 'name')
            try: type = int(cp.get(s, 'type'))
            except ConfigParser.NoOptionError: type = 0
            region = int(cp.get(s, 'region'))

            if selectregion is not None and region != selectregion:
                continue

            if simple:
                if type == 0: print '%03d' % id
                if type == 3: print '%03d' % id  
                continue

            if not enabled: en = " (DISABLED)"
            else: en = ""

            if type == 0:                
                x = int(cp.get(s, 'region_offset_x'))
                y = int(cp.get(s, 'region_offset_y'))
                w = int(cp.get(s, 'width'))
                h = int(cp.get(s, 'height'))                
                print "%03d: %-25s is terrain at (%d,%d) - (%d,%d) in region %d%s" % (
                    id, name, x, y, x+w-1, y+h-1, region, en)
            elif type == 1:
                print "%03d: %-25s is a city in region %d%s" % (id, name, region, en)
            elif type == 2:
                print "%03d: %-25s is a dungeon in region %d%s" % (id, name, region, en)
            elif type == 3:
                x = int(cp.get(s, 'region_offset_x'))
                y = int(cp.get(s, 'region_offset_y'))
                w = int(cp.get(s, 'width'))
                h = int(cp.get(s, 'height'))                
                print "%03d: %-25s is terrain at (%d,%d) - (%d,%d) in region %d%s" % (
                    id, name, x, y, x+w-1, y+h-1, region, en)              
            else:
                print "%03d: %-25s is something unknown (%d)%s" % (id, name, type, en)

    return 0

if __name__ == '__main__':
    try:
        import sys
        rv = run(sys.argv)
    except:
        import traceback
        traceback.print_exc()
        rv = 2

    sys.exit(rv)
    
# Changelog:
#   26-Jan-2002: Initial release
#   09-Feb-2002: Fixes for missing type= in epic zones
#   28-Oct-2002: Add -region, --simple options. Add region display.

#!/usr/bin/env python

# mapper.py: Dark Age of Camelot map generator.
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

import ConfigParser

try:
    import Image, ImageFont, ImageDraw
except ImportError, e:
    print "** Could not import PIL modules -- check PIL is installed **"
    print
    raise

try:
    import dempak, Zone, BumpmapRender, FixtureRender, ContourRender, BackgroundRender, RiverRender, SolidRender, BoundsRender, GridRender, CaptionRender, AltFixtureRender
except ImportError, e:
    print "** Could not import mapper support modules -- check your PYTHONPATH **"
    print
    raise

render_map = {
    'bumpmap':    BumpmapRender.BumpmapRender,
    'fixture':    FixtureRender.FixtureRender,
    'contour':    ContourRender.ContourRender,
    'background': BackgroundRender.BackgroundRender,
    'river':      RiverRender.RiverRender,
    'solid':      SolidRender.SolidRender,
    'bounds':     BoundsRender.BoundsRender,
    'grid':       GridRender.GridRender,
    'caption':    CaptionRender.CaptionRender,
    'altfixture': AltFixtureRender.FixtureRender
    }

def loadIncludes(settings):
    files = []
    while 1:
        for o in settings.options('maps'):
            if o[:7] == 'include':
                files.extend(settings.get('maps', o).split(','))
                settings.remove_option('maps', o)

        if not files: break

        settings.read(files[0])
        del files[0]

def loadRenderers(settings):
    renderers = []

    namelist = settings.get('maps', 'renderers')

    names = map(lambda x: x.strip().lower(), namelist.split(','))
    for name in names:
        type = settings.get(name, 'type').strip().lower()
        if not render_map.has_key(type):
            raise ConfigParser.Error, 'Unknown type "%s" for renderer "%s"' % (type, name)

        renderers.append((name, render_map[type]))

    return renderers

def drawByline(zone, out):
    try:
        byline = zone.settings.get('maps', 'byline')
        font = ImageFont.load(zone.settings.get('maps', 'bylinefont'))
        draw = ImageDraw.Draw(out)
        size = font.getsize(byline)
        draw.text( (out.size[0] - size[0] - 5, out.size[1] - size[1] - 5),
                   byline, font=font, fill=(255,255,255) )
        del draw
    except ConfigParser.NoOptionError: pass

def run(argv):
    settings = ConfigParser.ConfigParser()
    scale = 512
    region = (0,0,65536,65536)
    outpath = None
    location = None
    zoneID = None

    i = 1
    while i < len(argv):
        if argv[i] == '-settings':
            settings.read(argv[i+1])
            loadIncludes(settings)
            i += 1
        elif argv[i] == '-gamepath':
            settings.set('maps', 'gamepath', argv[i+1])
            i += 1
        elif argv[i] == '-polydir':
            settings.set('maps', 'polydir', argv[i+1])
            i += 1
        elif argv[i] == '-scale':
            try: scale = int(argv[i+1])
            except (ValueError,IndexError):
                print '-scale must be followed by a number'
                return 1
            i += 1
        elif argv[i] == '-location':
            location = argv[i+1]
            i += 1
        elif argv[i] == '-region':
            try:
                region = (int(argv[i+1]),int(argv[i+2]),int(argv[i+3]),int(argv[i+4]))
            except (ValueError,IndexError):
                print '-region must be followed by four numbers'
                return 1                
            i += 4
        elif argv[i] == '-zone':
            try:
                zoneID = int(argv[i+1])
            except (ValueError,IndexError):
                print '-zone must be followed by a number'
                return 1
            i += 1
        elif argv[i] == '-out':
            outpath = argv[i+1]
            i += 1
        elif argv[i] == '-renderers':
            settings.set('maps', 'renderers', argv[i+1])
            i += 1
        else:
            print "unknown option:", argv[i]
            return 1

        i += 1

    if not outpath:
        print "Please give an output filename (via -out <filename>)"
        return 1

    if not settings.has_section('maps'):
        print "No maps section found (did you specify -settings?)"
        return 1
    
    if location:
        lstr = settings.get('locations', location).split(',')
        zoneID = int(lstr[0])
        region = map(int,lstr[1:])

    if zoneID is None:
        print "Please specify either -zone <zoneID> or -location <location>"
        return 1

    if region[0] < 0 or region[2] > 65536 or region[0] >= region[2] or region[1] < 0 or region[3] > 65536 or region[1] >= region[3]:
        print "Bad region " + `region` + ": must be 0..65536 in both dimensions"
        return 1
        
    imgregion = (scale * region[0] / 65536,
                 scale * region[1] / 65536,
                 scale * region[2] / 65536,
                 scale * region[3] / 65536)

    renderers = loadRenderers(settings)

    zone = Zone.Zone(settings, zoneID, scale, imgregion[:2])
    
    imagesize = (imgregion[2] - imgregion[0], imgregion[3] - imgregion[1])
    print 'Mapping zone %d: %s to %s (%dx%d)' % (zoneID, `region`, outpath, imagesize[0], imagesize[1])
    zone.progress('Creating work area', 0.0)

    if zone.greyscale:
        out = Image.new('L', imagesize)
    else:
        out = Image.new('RGB', imagesize)
        
    for name, renderer in renderers:
        instance = renderer(zone, name)
        instance.render(out, (0,0,out.size[0],out.size[1]))
        del instance
        zone.progress(None)

    drawByline(zone, out)

    zone.progress('Writing ' + outpath, 0.0)
    out.save(outpath)
    zone.progress(None)
    del out
    del zone

    return 0

if __name__ == '__main__':
    import sys
    try:
        sys.exit(run(sys.argv))
    except ConfigParser.Error, e:
        print "Configuration error: " + `e`
        sys.exit(2)
    

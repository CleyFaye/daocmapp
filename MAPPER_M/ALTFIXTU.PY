# FixtureRender.py: DAoC mapper, fixture (structures/objects) rendering
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

# Settings options:
#   classify: name of section containing 'name=type' options used to classify
#     fixtures by .nif filename
#   <type>=<method>: draw fixtures classified as 'type' via the fixture
#     rendering option in section 'method'
#   <file>=<method>: draw 'file'.nif using method 'method'

# Method section options:
#    layer=n:        controls fixture drawing order
#
#    type=none:         don't draw fixture at all
#    type=wireframe:    draw only fixture wireframe
#      color=<color>:   draw wireframe in this color
#    type=solid:        draw the fixture wireframe, filled
#      fill=<color>:    fill with this color
#      outline=<color>: outline the wireframe with this color
#    type=shaded:       draw the fixture flat-shaded
#      color=<color>:   use this color as the base color

import re, math, os, stat, ConfigParser
import Image, ImageDraw
import AltNIFToPoly, Tiler, dempak, Util

#
# NIF renderers
#

class ShadedNIF:
    def __init__(self, color, polylist, layer, lv, lmin, lmax):
        self.layer = layer
        self.polys = []
        self.color = color
        self.lv = lv
        self.lmin = lmin
        self.lmax = lmax

        minx = None
        self.maxz = None
        for poly in polylist:
            # face normal
            n = Util.normalize(Util.normal(poly[0], poly[1], poly[2]))
            
            # backface cull
            if n[2] < 0.0: continue

            # shade face
            nzlz = n[2] * lv[2]

            # sort faces on z
            plist = []
            local_maxz = poly[0][2]
            for x,y,z in poly:
                if not minx:
                    minx = maxx = x
                    miny = maxy = y
                else:
                    if x < minx: minx = x
                    elif x > maxx: maxx = x
                    if y < miny: miny = y
                    elif y > maxy: maxy = y

                if z > local_maxz: local_maxz = z                    
                plist.append( (x,y) )
                
            l = (local_maxz, n[0:2], nzlz, tuple(plist))
            self.polys.append(l)

            if not self.maxz or local_maxz > self.maxz:
                self.maxz = local_maxz

        self.polys.sort()

        r1 = math.sqrt(minx*minx + miny*miny)
        r2 = math.sqrt(maxx*maxx + maxy*maxy)
        if r1 > r2: self.radius = r1
        else: self.radius = r2

    def draw(self, zone, canvas, ox, oy, a, mag):
        sina = math.sin(a * math.pi / 180.0)
        cosa = math.cos(a * math.pi / 180.0)

        # draw in Z order
        for dummy, normal, nzlz, plist in self.polys:
            # note we effectively flip the Y sign here to
            # compensate for geometry vs. screen Y axis having
            # different signs

            rn = (normal[0] * cosa + normal[1] * sina,
                  normal[0] * sina - normal[1] * cosa)                
            
            ndotl = nzlz + rn[0] * self.lv[0] + rn[1] * self.lv[1]
            if ndotl > 0.0: ndotl = 0.0
            lighting = self.lmin - (self.lmax - self.lmin) * ndotl
            
            if zone.greyscale:
                shade = self.color * lighting
            else:
                shade = (self.color[0] * lighting,
                         self.color[1] * lighting,
                         self.color[2] * lighting,
                         self.color[3])
                    
            pl = []
            for x,y in plist:
                # note we effectively flip the Y sign here to
                # compensate for geometry vs. screen Y axis having
                # different signs
                newX = ox + (x * cosa + y * sina) * mag / 100
                newY = oy + (x * sina - y * cosa) * mag / 100
                pl.append( (zone.RToIScale(newX), zone.RToIScale(newY)) )

            canvas.polygon(pl, fill=shade, outline=shade)

class PolyNIF:
    def __init__(self, outline, fill, polylist, layer):
        self.fill = fill
        self.outline = outline
        self.polylist = polylist
        self.layer = layer
        self.maxz = 0

        minx = None
        for poly in polylist:
            for x,y,z in poly:
                if not minx: minx = maxx = miny = maxy = x
                else:
                    if x < minx: minx = x
                    elif x > maxx: maxx = x
                    if y < miny: miny = y
                    elif y > maxy: maxy = y

        r1 = math.sqrt(minx*minx + miny*miny)
        r2 = math.sqrt(maxx*maxx + maxy*maxy)
        if r1 > r2: self.radius = r1
        else: self.radius = r2

    def draw(self, zone, canvas, ox, oy, a, mag):
        sina = math.sin(a * math.pi / 180.0)
        cosa = math.cos(a * math.pi / 180.0)

        for poly in self.polylist:
            pl = []
            for x,y,z in poly:
                # note we effectively flip the Y sign here to
                # compensate for geometry vs. screen Y axis having
                # different signs
                newX = ox + (x * cosa + y * sina) * mag / 100
                newY = oy + (x * sina - y * cosa) * mag / 100
                pl.append( (zone.RToIScale(newX), zone.RToIScale(newY)) )

            canvas.polygon(pl, fill=self.fill, outline=self.outline)

class MissingNIF:
    def __init__(self, file):
        self.file = file
        self.layer = 1
        self.warned = 0
        self.radius = 0
        self.maxz = 0
    
    def draw(self, zone, canvas, ox, oy, a, mag):
        if not self.warned:
            print  "warning: use of missing NIF " + self.file
            self.warned = 1

#
# Polygon loader
#

_cache = {}

def readPolys(zone, file):
    # We try to be smart about mtimes here.
    #print "looking for %s" % file
    # Locate the right .npk
    Housing=0
    npkpath = os.path.join(zone.gamepath, 'zones', 'zone%03d' % zone.zoneID, 'nifs', file + '.npk')
    npkpathHous = os.path.join(zone.gamepath,'phousing', 'zones', 'zone%03d' % zone.zoneID, 'nifs', file + '.npk')
    if not os.path.exists(npkpathHous):
      npkpathHous = os.path.join(zone.gamepath,'phousing', 'nifs', file + '.npk')
    polypath = os.path.join(zone.polydir, file + ".%03d.poly" % zone.zoneID)
    if not os.path.exists(npkpath):
        npkpath = os.path.join(zone.gamepath, 'zones', 'nifs', file + '.npk')
        polypath = os.path.join(zone.polydir, file + ".poly")

    if _cache.has_key(polypath):
        return _cache[polypath]

    try:
        poly_mtime = os.stat(polypath)[stat.ST_MTIME];
        poly_ok = 1
    except OSError, e:
        poly_mtime = 0
        poly_ok = 0

    try:
        npk_mtime = os.stat(npkpath)[stat.ST_MTIME]
        npk_ok = 1
    except OSError, e:
        npk_mtime = 0
        npk_ok = 0
        
    if not npk_ok:
     try:
        npk_mtime = os.stat(npkpathHous)[stat.ST_MTIME]
        npk_ok = 1
        Housing = 1
     except OSError, e:
        npk_mtime = 0
        npk_ok = 0
        
    polylist = None
    
    if npk_mtime > poly_mtime and npk_ok:
        # Need to recreate the .poly file.
        if Housing :
         print  "Converting " + npkpathHous + " to " + polypath + " ..."
        else: 
         print "Converting " + npkpath + " to " + polypath + " ..."

        try:
            if Housing:
              npk = dempak.MPAKFile(npkpathHous)
            else:  
              npk = dempak.MPAKFile(npkpath)            
            nif = npk.open(file + '.nif')
            nifdata = nif.read()
            nif.close()
            npk.close()
            
            nodemap, first = AltNIFToPoly.load(nifdata)
            polylist = nodemap[first].poly(nodemap, AltNIFToPoly.null_xform)
            del nodemap
            del first

            # We don't really care if this fails.
            if not os.path.isdir(zone.polydir): os.mkdir(zone.polydir)
            AltNIFToPoly.savePolys(polylist, polypath)
        except (AltNIFToPoly.error, IOError):
            import traceback
            traceback.print_exc()

    if not polylist and poly_ok:
        try:
            polylist = AltNIFToPoly.loadPolys(polypath)
        except IOError, e:
            import traceback
            traceback.print_exc()

    _cache[polypath] = polylist

    return polylist

#
# Renderer
#

class FixtureRender(Tiler.Tiler):
    def __init__(self, zone, name):
        Tiler.Tiler.__init__(self, zone, name)

    def preRender(self):
        self.readNIFs()
        self.readFixtures()

    _re_NIF = re.compile(r'(\d+),[^,]+,([^,]+)\.nif,\d+,\d+,(\d+),.*', re.IGNORECASE)
    def readNIFs(self):
        try: classify = self.zone.settings.get(self.name, 'classify')
        except ConfigParser.NoOptionError: classify = None
        
        self.nifmap = {}
        nifs = self.zone.datafile('nifs.csv')
        for l in nifs.readlines():
            match = FixtureRender._re_NIF.match(l)
            if match:
                id, file, color = match.groups()
            
                file = file.lower()
                id = int(id)
                color = int(color)

                # Classify the NIF.
                classname = file
                if classify:
                    try: classname = self.zone.settings.get(classify, file)
                    except ConfigParser.NoOptionError: pass

                try: variant = self.zone.settings.get(self.name, classname)
                except ConfigParser.NoOptionError: variant = self.zone.settings.get(self.name, 'default')

                # Find settings.
                type = self.zone.settings.get(variant, 'type').lower().strip()
                if type == 'none':
                    self.nifmap[id] = None
                    continue

                if color == 0: default = (255, 255, 255, 255)
                else: default = (color%256, (color/256)%256, color/65536, 255)
                layer = self.zone.settings.getint(variant, 'layer')

                polylist = readPolys(self.zone, file)
                #i produce ncarcass.poly who whas invalide in 1.62 and 1.63 invalide file, Daoc Client dont understant this file exept collide
                #all point are the same so i catch it
                toclear = 0
                #i place ncarcass = erreur in [fixture-classes] so i dont renderer this piles of meat
                #~ if polylist :
                   #~ for poly in polylist :
                     #~ for x, y, z in poly :
                       #~ if x==y and x==z and y==z :  toclear=1
                       
                if polylist and not toclear:
                    if type == 'wireframe':
                        color = self.zone.getColor(variant, 'color', default)
                        self.nifmap[id] = PolyNIF(color, None, polylist, layer)
                    elif type == 'solid':
                        o = self.zone.getColor(variant, 'outline', default)
                        f = self.zone.getColor(variant, 'fill', default)
                        self.nifmap[id] = PolyNIF(o, f, polylist, layer)
                    elif type == 'shaded':                        
                        color = self.zone.getColor(variant, 'color', default)
                        try:
                            s = self.zone.settings.get(variant, 'light_vector')
                            lv = map(float, s.split(','))
                        except ConfigParser.NoOptionError: lv = (-1.0,1.0,-1.0)
                        lv = Util.normalize(lv)

                        try: lmin = float(self.zone.settings.get(variant, 'light_min'))
                        except ConfigParser.NoOptionError: lmin = 0.5
                        try: lmax = float(self.zone.settings.get(variant, 'light_max'))
                        except ConfigParser.NoOptionError: lmax = 1.0

                        self.nifmap[id] = ShadedNIF(color, polylist, layer, lv, lmin, lmax)
                    else:
                        raise RuntimeError, 'unknown NIF type: ' + type
                else:
                    if toclear : print "I've found an invalide polylist"
                    self.nifmap[id] = MissingNIF(file)
            
        nifs.close()

    _re_Fixture = re.compile(r'\d+,(\d+),[^,]+,(\d+),(\d+),\d+,(\d+),(\d+),.*')
    def readFixtures(self):
        self.layers = {}
        fixtures = self.zone.datafile('fixtures.csv')
        for l in fixtures.readlines():
            match = FixtureRender._re_Fixture.match(l)
            if match:
                nifId = int(match.group(1))
                try:
                  nif = self.nifmap[nifId]
                except:
                  print "I don't anderstand " + l 
                  nif = None
                if not nif: continue
                x = int(match.group(2))
                y = int(match.group(3))
                a = int(match.group(4))
                mag = int(match.group(5))

                zkey = nif.maxz * a
                data = (zkey,x,y,a,mag,nif)

                if self.layers.has_key(nif.layer):
                    self.layers[nif.layer].append(data)
                else:
                    self.layers[nif.layer] = [data]

        fixtures.close()

        layers = self.layers.keys();
        layers.sort()
        for layer in layers:
            self.layers[layer].sort()

    # Temporary images needed:
    #   greyscale: 3xL(tilesize)
    #   colour:    2xRGB(tilesize) + 1xRGBA(tilesize)
    def renderTile(self, destimage, tile):
        tilesize = (tile[2] - tile[0], tile[3] - tile[1])
        
        minpt = self.zone.IToR(tile[0:2])
        maxpt = self.zone.IToR(tile[2:4])

        layerlist = self.layers.keys();
        layerlist.sort()
        for layer in layerlist:
            if self.zone.greyscale:
                image = Image.new('L', tilesize, 0)
            else:
                image = Image.new('RGBA', tilesize, (0,0,0,0))

            draw = ImageDraw.ImageDraw(image)

            for zkey, x, y, a, mag, nif in self.layers[layer]:
                r = nif.radius * mag / 100
                if (x + r) < minpt[0] or (x - r) > maxpt[0] or (y + r) < minpt[1] or (y - r) > maxpt[1]:
                    continue  # not on this tile.
            
                nif.draw(self.zone, draw, x - minpt[0], y - minpt[1], a, mag)
            
            if self.zone.greyscale:
                destimage.paste(0, tile, image)
            else:
                destimage.paste(image, tile, image)

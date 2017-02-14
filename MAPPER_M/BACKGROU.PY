# BackgroundRender.py: DAoC mapper background image renderer
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

# Settings options: none

import ConfigParser, os, Image, ImageFilter
import dempak, Tiler, DdsImageFile

class BackgroundRender(Tiler.Tiler):
    def __init__(self, zone, name):
        Tiler.Tiler.__init__(self, zone, name)

        # These are needed for the epic zones.
        try: self.zoneID = zone.sector_dat.getint('terrain', 'use_texture')
        except ConfigParser.NoOptionError: self.zoneID = zone.zoneID
        # modified for the handle of houssing zone
        try: 
           tx = zone.sector_dat.get('terrain', 'flip_x')
           print tx
           if  (tx == '1') or (tx !='-1'):
              self.flip_x = True 
           else: 
              self.flip_x = False
        except ConfigParser.NoOptionError: self.flip_x = 0
        
        try: 
          ty = zone.sector_dat.get('terrain', 'flip_y')
          print ty
          if ty == '1' or ty =='-1' :
            self.flip_y = True
          else :
            self.flip_y = False  
        except ConfigParser.NoOptionError: self.flip_y = 0

    # Temporary images:
    #  colour: ~2*RGB(tilesize)
    #  greyscale: ~2*L(tilesize)
    def renderTile(self, destimage, tile):
        try: 
          texfile = dempak.MPAKFile(os.path.join(self.zone.gamepath, 'zones', 'zone%03d' % self.zoneID, 'tex%03d.mpk' % self.zoneID))
        except IOError, e:
          texfile = dempak.MPAKFile(os.path.join(self.zone.gamepath,'phousing', 'zones', 'zone%03d' % self.zoneID, 'tex%03d.mpk' % self.zoneID))
          
        # decide if we need to use .bmp or .dds images
        try:
            texfile.open('tex00-00.dds').close()
            sourcesize = 512
            usedds = 1
        except IOError, e:
            sourcesize = 256
            usedds = 0

        sourcescale = 8192.0 / sourcesize

        # Calculate the "interesting" range of background tiles for this
        # output tile
        if self.flip_x:
            xl = int((65536 - self.zone.IToRX(tile[2]) - 8191) / 8192)
            xh = int((65536 - self.zone.IToRX(tile[0])) / 8192)
        else:
            xl = int(self.zone.IToRX(tile[0]) / 8192)
            xh = int((self.zone.IToRX(tile[2]) + 8191) / 8192)

        if self.flip_y:
            yl = int((65536 - self.zone.IToRY(tile[3]) - 8191) / 8192)
            yh = int((65536 - self.zone.IToRY(tile[1])) / 8192)
        else:
            yl = int(self.zone.IToRY(tile[1]) / 8192)
            yh = int((self.zone.IToRY(tile[3]) + 8191) / 8192)
        
        for y in xrange(yl, yh+1):
            if y < 0 or y > 7: continue
            if self.flip_y: basey = 65556 - (y+1) * 8192
            else: basey = y * 8192
            miny = self.zone.RToIY(basey)
            maxy = self.zone.RToIY(basey + 8192)
            if maxy < tile[1] or miny > tile[3]: continue
            
            for x in xrange(xl, xh+1):
                if x < 0 or x > 7: continue
                if self.flip_x: basex = 65556 - (x+1) * 8192
                else: basex = x * 8192
                minx = self.zone.RToIX(basex)
                maxx = self.zone.RToIX(basex + 8192)
                if maxx < tile[0] or minx > tile[2]: continue

                # Now jump through lots of hoops to avoid resizing the
                # entire source image (that kills us on very large scales,
                # regardless of the actual tile or region size, since at
                # e.g. scale=16384, each background image becomes a
                # 2048x2048 image...)

                # Calculate bounds of tile on this image
                srcbounds = [int((self.zone.IToRX(tile[0]) - basex) / sourcescale + 0.5) - 1,
                             int((self.zone.IToRY(tile[1]) - basey) / sourcescale + 0.5) - 1,
                             int((self.zone.IToRX(tile[2]) - basex) / sourcescale + 0.5) + 1,
                             int((self.zone.IToRY(tile[3]) - basey) / sourcescale + 0.5) + 1]

                # Crop to actual source dimensions
                if srcbounds[0] < 0: srcbounds[0] = 0
                if srcbounds[1] < 0: srcbounds[1] = 0
                if srcbounds[2] > sourcesize: srcbounds[2] = sourcesize
                if srcbounds[3] > sourcesize: srcbounds[3] = sourcesize
                if srcbounds[2] <= srcbounds[0] or srcbounds[3] <= srcbounds[1]: continue # no image on this tile.

                # Determine the projection of this source rectangle onto the destination image.
                destbounds = [self.zone.RToIX(basex + srcbounds[0] * sourcescale),
                              self.zone.RToIY(basey + srcbounds[1] * sourcescale),
                              self.zone.RToIX(basex + srcbounds[2] * sourcescale),
                              self.zone.RToIY(basey + srcbounds[3] * sourcescale)]

                # Determine what to resize the image to.
                resize_to = (destbounds[2] - destbounds[0],destbounds[3] - destbounds[1])

                # Clip destbounds against the actual tile. Remember where the clipping occurs.
                usebounds = [0,0,destbounds[2]-destbounds[0],destbounds[3]-destbounds[1]]
                if destbounds[0] < tile[0]:
                    usebounds[0] += tile[0] - destbounds[0]
                    destbounds[0] = tile[0]                    
                if destbounds[1] < tile[1]:
                    usebounds[1] += tile[1] - destbounds[1]
                    destbounds[1] = tile[1]
                if destbounds[2] > tile[2]:
                    usebounds[2] -= destbounds[2] - tile[2]
                    destbounds[2] = tile[2]
                if destbounds[3] > tile[3]:
                    usebounds[3] -= destbounds[3] - tile[3]
                    destbounds[3] = tile[3]

                #print tile, srcbounds, resize_to, usebounds, destbounds
                
                # Acquire and crop/resize/etc image
                if usedds: 
                      i = texfile.open('tex%02d-%02d.dds' % (x,y))
                      tempdata = i.read()
                      fichiertemp = open('temp%02d-%02d.dds' % (x,y), 'wb')
                      fichiertemp.write(tempdata)
                      fichiertemp.close()
                      # if you uses dx9sdk
                      #os.pawnv(os.P_WAIT,'..\\bin\\texconv.exe', '-nologo -ft R8G8B8 -f BMP -m 1 -if NONE temp.dds')
                      os.system('texconv.exe -nologo -ft BMP -m 1 -if NONE temp%02d-%02d.dds' % (x,y)) 
                      #if you uses dxtools from nvdia
                      #os.system('dx2tg.bat')
                      i = Image.open('temp%02d-%02d.bmp' % (x,y))
                      
                else: i = Image.open(texfile.open('tex%02d-%02d.bmp' % (x, y)))

                if self.flip_x: i = i.transpose(Image.FLIP_LEFT_RIGHT)
                if self.flip_y: i = i.transpose(Image.FLIP_TOP_BOTTOM)
                if self.zone.greyscale: i = i.convert('L')
                else: i = i.convert('RGB')

                i = i.crop(srcbounds)
                i = i.resize(resize_to, Image.BILINEAR)
                i = i.crop(usebounds)

                # Paste tile.
                destimage.paste(i, destbounds)

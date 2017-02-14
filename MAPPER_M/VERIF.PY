#!/usr/bin/env python

# FixtureRender.py: DAoC mapper, fixture (structures/objects) rendering
# See http://www.randomly.org/projects/mapper/ for updates and sample output.

# Copyright (c) 2003, Fabrice Marmont <fabrice.Marmont@Wanadoo.fr>
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

import dempak, NIFToPoly, os, sys

class error(Exception): pass


mode = 'bin'
#~ print sys.argv[0], sys.argv[1]
if len(sys.argv) < 2:
  print "Usage: %s  file.npk ..." % sys.argv[0]
  raise error, "invalide syntax"
npkpath = sys.argv[1]
print >>sys.stderr, npkpath
if os.path.exists(npkpath):
         npk = dempak.MPAKFile(npkpath)
         file,npkpath = os.path.split(npkpath)
         file,ext = os.path.splitext(npkpath)
         nif = npk.open(file + '.nif')
         nifdata = nif.read()
         nif.close()
         npk.close()
         nodemap, first = NIFToPoly.load(nifdata)
         if not nodemap.has_key(first):
                print "oops "+file
                raise error, "No root node found - urk!"
         else:
               polylist = nodemap[first].poly(nodemap, NIFToPoly.null_xform)
               outfile = os.path.join('shaded',file+'.png')
               NIFToPoly.drawShaded(polylist, outfile)

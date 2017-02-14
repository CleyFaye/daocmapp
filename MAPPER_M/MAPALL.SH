#!/bin/sh

# This is what I use to generate the maps on my website
# (see http://www.randomly.org/projects/mapper).

# Placed in the public domain.
# Oliver Jowett <oliver@randomly.org>   28/10/2002

#for jeux in camelot Shrouded_Isles; do
#jeux=Shrouded_Isles
jeux=Camelot
source=d:\\mythic\\$jeux
bindir=.
font=.\\6x12-ISO8859-1.pil

set -e

mkdir -p out work
#~ rm -f polys/*.*

zonesA=`python zonelist.py -gamepath $source -region 001 -simple`
zonesM=`python zonelist.py -gamepath $source -region 100 -simple`
zonesH=`python zonelist.py -gamepath $source  -region 200 -simple`

zonesSIA=`python zonelist.py -gamepath $source -region 051 -simple`
zonesSIM=`python zonelist.py -gamepath $source -region 151 -simple`
zonesSIH=`python zonelist.py -gamepath $source -region 181 -simple`

zonesHA=`python zonelist.py -gamepath $source -region 002 -simple`
zonesHM=`python zonelist.py -gamepath $source -region 102 -simple`
zonesHH=`python zonelist.py -gamepath $source -region 202 -simple`

for z in $zonesHA $zonesHM $zonesHH $zonesSIA $zonesSIM $zonesSIH $zonesA $zonesM $zonesH 
do
 ./2z.bat ${z}
 ./1z.bat ${z}
done

for z in 002 102 202 051 151 181 001 100 200
do
  python glue.py -gamepath $source -out work\\region${z}.png -scale 10 -fontpath $font -template work\\map%03d_o.png -region $z >out/region$z.imagemap
done
@echo off
set rivset=%2
if "%rivset%"=="" goto redef
goto doit
:redef
set rivset=d
:doit
python mapper.py -settings overview.ini -settings river%rivset%.ini -gamepath f:\jeux\toa -scale 128 -zone %1 -out out\map%1_o.png
del *.bmp /Q

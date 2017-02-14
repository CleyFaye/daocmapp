@echo off
set rivset=%2
if "%rivset%"=="" goto redef
goto doit
:redef
set rivset=d
:doit
python mapper.py -settings everything.ini -settings river%rivset%.ini -gamepath f:\jeux\toa -scale 1024 -zone %1 -out out\map%1.png
del *.bmp /Q

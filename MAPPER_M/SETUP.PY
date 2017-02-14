from distutils.core import setup, Extension

_dxt1 = Extension('_dxt1',
                    sources = ['dxt1-decoder.c'])

setup (name = 'dxt1Decoder',
       version = '1.0',
       description = 'util pour daoc mapper',
       ext_modules = [_dxt1])


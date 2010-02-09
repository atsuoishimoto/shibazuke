from distutils.core import setup
from Pyrex.Distutils import build_ext, Extension

setup(name='Shibazuke',
      version='0.0.1',
      ext_modules=[
          Extension('shibazuke', ['shibazuke.pyx'])],
      cmdclass = {'build_ext': build_ext},
)



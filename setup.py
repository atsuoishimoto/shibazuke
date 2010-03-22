import ez_setup
ez_setup.use_setuptools()

from setuptools import setup, Extension

setup(name='Shibazuke',
      version='0.1.1',
      description="Fast object serializer for Python", 
      classifiers = [
          "Intended Audience :: Developers",
          "License :: OSI Approved :: MIT License",
          "Programming Language :: Python",
          "Topic :: Software Development :: Libraries :: Python Modules"],
      author="Atsuo Ishimoto",
      author_email="ishimoto@gembook.org",
      url="https://launchpad.net/shibazuke",
      license="MIT License",
      platforms=['any'],

      ext_modules=[
          Extension('shibazuke', ['shibazuke.pyx'])]
)


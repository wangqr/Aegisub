#! /bin/bash

set -e

if [ $TRAVIS_OS_NAME = 'osx' ]; then
  brew install autoconf ffmpeg freetype gettext ffms2 fftw fribidi libass m4 icu4c boost wxmac lua
else
  sudo luarocks install busted > /dev/null
  sudo luarocks install moonscript > /dev/null
  sudo luarocks install uuid > /dev/null
  # Remove the CMake provided by travis
  sudo rm -rf /usr/local/cmake*
  if [ "$BUILD_SUIT" = "autotools" ]; then
    sudo pip install -U cpp-coveralls;
    git submodule --quiet init;
    git submodule --quiet update vendor/googletest;
  else
    pushd /usr/src/googletest;
    sudo cmake .;
    sudo make install -j2;
    popd;
  fi
fi

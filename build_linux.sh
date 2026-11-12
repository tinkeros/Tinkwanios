#! /bin/bash

# rebuild aiwnios

rm -rf build
mkdir build;cd build;
cmake ..;
make -j$(nproc);
cd ..;

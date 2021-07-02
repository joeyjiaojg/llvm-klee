#!/bin/bash
set -e

LLVM_VERSION=12
[ "$1" != "" ] && LLVM_VERSION=$1
CWD=$(pwd)
WS=${CWD}/klee

# set env
git config --global user.email joeyjiaojg@gmail.com
git config --global user.name "Joey Jiao"

# Install klee dependency
sudo apt-get install -y build-essential curl libcap-dev git cmake libncurses5-dev unzip libtcmalloc-minimal4 libgoogle-perftools-dev libsqlite3-dev doxygen z3
sudo apt install -y linux-libc-dev ca-certificates
mkdir -p $WS
cd $WS

# Install Python packages
cd $WS
pip install lit tabulate wllvm

# Install cmake
cd $WS
if [ ! -d /usr/local/cmake-3.20.5-linux-x86_64 ]; then
wget https://github.com/Kitware/CMake/releases/download/v3.20.5/cmake-3.20.5-linux-x86_64.tar.gz
tar -C /usr/local/ -xf cmake-3.20.5-linux-x86_64.tar.gz
echo "export PATH=/usr/local/cmake-3.20.5-linux-x86_64/bin:\$PATH" >> ~/.bashrc
fi
export PATH=/usr/local/cmake-3.20.5-linux-x86_64/bin:$PATH

# Install llvm
#sudo bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"
if [ "$(which clang-${LLVM_VERSION})" == "" ]; then
code=$(lsb_release -c | awk '{print $NF}')
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
echo "deb http://apt.llvm.org/$code/ llvm-toolchain-${code}-${LLVM_VERSION} main" | sudo tee -a /etc/apt/sources.list
sudo apt update
sudo apt install -y llvm-${LLVM_VERSION} llvm-${LLVM_VERSION}-dev llvm-${LLVM_VERSION}-tools clang-${LLVM_VERSION}
fi

# Install STP
cd $WS
if [ "$(which stp)" == "" ]; then
sudo apt-get install -y cmake bison flex libboost-all-dev perl zlib1g-dev minisat
sudo apt install -y minisat
git clone https://github.com/stp/stp.git
cd stp
git checkout tags/2.3.3
mkdir -p build
cd build
cmake ..
make -j$(nproc)
sudo make install
fi

# Install Google Test
cd $WS
if [ ! -f release-1.7.0.zip ]; then
curl -OL https://github.com/google/googletest/archive/release-1.7.0.zip
rm -rf release-1.7.0
unzip release-1.7.0.zip
fi

# Build uClibc
cd $WS
if [ ! -d klee-uclibc ]; then
git clone https://github.com/klee/klee-uclibc.git 
cd klee-uclibc
./configure --make-llvm-lib --with-llvm-config=/usr/bin/llvm-config-${LLVM_VERSION}
make -j$(nproc)
cd ..
fi

# Build klee
cd $WS
if [ ! -d klee ]; then
git clone https://github.com/klee/klee.git
cd klee
git fetch https://github.com/joeyjiaojg/klee.git 5edaa4c6d9714fa3c16ee9d0d3fed2abd9aa58ef && git cherry-pick FETCH_HEAD
## Build libc++
LLVM_VERSION=${LLVM_VERSION} SANITIZER_BUILD= BASE=$WS/klee/libcxx REQUIRES_RTTI=1 DISABLE_ASSERTIONS=1 ENABLE_DEBUG=0 ENABLE_OPTIMIZED=1 ./scripts/build/build.sh libcxx
fi

## build klee with libcxx
cd $WS/klee
mkdir -p build
cd build
cmake \
  -DENABLE_SOLVER_STP=ON \
  -DENABLE_POSIX_RUNTIME=ON \
  -DENABLE_KLEE_UCLIBC=ON \
  -DKLEE_UCLIBC_PATH=$WS/klee-uclibc/ \
  -DENABLE_UNIT_TESTS=ON \
  -DGTEST_SRC_DIR=$WS/googletest-release-1.7.0/ \
  -DLLVM_CONFIG_BINARY=/usr/bin/llvm-config-${LLVM_VERSION} \
  -DLLVMCC=/usr/bin/clang-${LLVM_VERSION} \
  -DLLVMCXX=/usr/bin/clang++-${LLVM_VERSION} \
  -DENABLE_KLEE_LIBCXX=ON \
  -DKLEE_LIBCXX_DIR=$WS/klee/libcxx/libc++-install-${LLVM_VERSION}0 \
  -DKLEE_LIBCXX_INCLUDE_DIR=$WS/klee/libcxx/libc++-install-${LLVM_VERSION}0/include/c++/v1 \
  -DENABLE_KLEE_EH_CXX=ON \
  -DKLEE_LIBCXXABI_SRC_DIR=$WS/klee/libcxx/llvm-${LLVM_VERSION}0/libcxxabi/ ..
make -j$(nproc)
sudo make install

echo "Done!"

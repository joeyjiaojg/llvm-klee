FROM debian:buster

WORKDIR /local/mnt/workspace
VOLUME /local/mnt/workspace

# Install basic packages
RUN apt-get update
RUN apt-get install -y git apt-utils build-essential wget curl vim lsb-release ninja-build software-properties-common sudo

# Install python
RUN apt-get install -y python3 python3-distutils python3-dev

# Install pip
RUN wget https://bootstrap.pypa.io/get-pip.py && python3 get-pip.py && rm get-pip.py
RUN pip install wllvm

# Install klee
COPY setup_klee.sh /local/mnt/workspace
RUN bash setup_klee.sh
RUN rm -rf klee && rm -rf setup_klee.sh

# Install llvm-klee
RUN git clone https://github.com/joeyjiaojg/llvm-project -b llvmklee
RUN cd llvm-project && mkdir build && cd build && cmake -G Ninja -DCMAKE_BUILD_TYPE=DEBUG ../llvm && ninja -j$(nproc) llvm-klee && ninja tools/llvm-klee/install
RUN rm -rf llvm-project

# Copyright 2022 Primihub
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


FROM ubuntu:18.04 as builder

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install python 3.9
RUN apt update && apt install -y software-properties-common  
RUN add-apt-repository ppa:deadsnakes/ppa 
RUN  apt-get update \
  && apt-get install -y python3.9 libgmp-dev software-properties-common 
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 2
RUN update-alternatives --config python3

# install other dependencies
RUN apt-get install -y gcc-8 automake ca-certificates git g++-8 libtool m4 patch pkg-config python3.9-dev python-dev unzip make wget curl zip ninja-build libgmp-dev \
  && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8 

# install npm 
RUN apt-get install -y npm

# install cmake
RUN wget https://primihub.oss-cn-beijing.aliyuncs.com/cmake-3.20.2-linux-x86_64.tar.gz \
  && tar -zxf cmake-3.20.2-linux-x86_64.tar.gz \
  && chmod +x cmake-3.20.2-linux-x86_64/bin/cmake \
  && ln -s `pwd`/cmake-3.20.2-linux-x86_64/bin/cmake /usr/bin/cmake \
  && rm -rf /var/lib/apt/lists/* cmake-3.20.2-linux-x86_64.tar.gz 

# install bazelisk
RUN npm install -g @bazel/bazelisk

WORKDIR /src
ADD . /src

# Update pybind11 link options in BUILD.bazel
RUN CONFIG=`python3.9-config --ldflags` \
  && NEWLINE="\ \ \ \ linkopts = LINK_OPTS + [\"${CONFIG}\"]," \
  && sed -i "451c ${NEWLINE}" BUILD.bazel

# Bazel build primihub-node & primihub-cli
RUN bazel build --config=linux :node :cli

FROM ubuntu:18.04 as runner

# Install python 3.9
RUN apt update && apt install -y software-properties-common  
RUN add-apt-repository ppa:deadsnakes/ppa 
RUN  apt-get update \
  && apt-get install -y python3.9 libgmp-dev software-properties-common 
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 2
RUN update-alternatives --config python3
RUN apt install -y curl python3.9-distutils && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
  && python3 get-pip.py --user \
  && rm -f get-pip.py


# RUN rm -rf /var/lib/apt/lists/*

ARG TARGET_PATH=/root/.cache/bazel/_bazel_root/f8087e59fd95af1ae29e8fcb7ff1a3dc/execroot/__main__/bazel-out/k8-fastbuild/bin
WORKDIR $TARGET_PATH
# Copy binaries to TARGET_PATH
COPY --from=builder $TARGET_PATH ./
# Copy test data files to /tmp/
COPY --from=builder /src/data/ /tmp/
# Make symlink to primihub-node & primihub-cli
RUN mkdir /app && ln -s $TARGET_PATH/node /app/primihub-node && ln -s $TARGET_PATH/cli /app/primihub-cli

# Change WorkDir to /app
WORKDIR /app
# Copy all test config files to /app
COPY --from=builder /src/config ./

# Copy primihub python sources to /app and setup to system python3
RUN mkdir primihub_python
COPY --from=builder /src/python/ ./primihub_python/

WORKDIR /app/primihub_python
RUN ls -l *
RUN python3.9 -m pip install -r requirements.txt && python3.9 setup.py install 
WORKDIR /app

# gRPC server port
EXPOSE 50050
# Cryptool port
EXPOSE 12120
EXPOSE 12121





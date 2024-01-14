# Copyright 2024, Tim Hockin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Pick your favorite base image.  Debian is very standard but large.  Alpine is
# less expansive, but smaller.
FROM debian as base

# We can be sloppy about layers because this is a multi-stage build.
RUN apt-get -y -qq -o Dpkg::Use-Pty=0 update
RUN apt-get -y -qq -o Dpkg::Use-Pty=0 -y upgrade

# Install the tools you need
RUN apt-get -y -qq -o Dpkg::Use-Pty=0 -y install \
	bash \
	grep \
	sed \
	gawk \
	coreutils \
	jq \
	diffutils
RUN rm -rf /var/lib/apt/lists/*

# Update this as needed.
FROM registry.k8s.io/kubernetes/kubectl:v1.29.0 as kubectl

FROM scratch

COPY --from=base / /
COPY --from=kubectl /bin/kubectl /bin/kubectl

# This image has no ENTRYPOINT or CMD.

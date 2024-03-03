# Where to push the docker image.
REGISTRY ?= thockin
NAME ?= kubectl-sidecar
VERSION ?= v1.29.2

# Set these to cross-compile.
GOOS ?=
GOARCH ?=

# Set this to 1 to build a debugger-friendly binary.
DBG ?=

###
### These variables should not need tweaking.
###

ALL_PLATFORMS := linux/amd64 linux/arm64 linux/ppc64le linux/s390x

# Used internally.  Users should pass GOOS and/or GOARCH.
OS := $(if $(GOOS),$(GOOS),$(shell go env GOOS))
ARCH := $(if $(GOARCH),$(GOARCH),$(shell go env GOARCH))

IMAGE := $(REGISTRY)/$(NAME)
TAG := $(VERSION)
OS_ARCH_TAG := $(TAG)__$(OS)_$(ARCH)

DBG_MAKEFILE ?=
ifneq ($(DBG_MAKEFILE),1)
    # If we're not debugging the Makefile, don't echo recipes.
    MAKEFLAGS += -s
endif

all: container

# For the following OS/ARCH expansions, we transform OS/ARCH into OS_ARCH
# because make pattern rules don't match with embedded '/' characters.

container-%:
	$(MAKE) container                     \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

push-%:
	$(MAKE) push                          \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

all-container: $(addprefix container-, $(subst /,_, $(ALL_PLATFORMS)))

all-push: $(addprefix push-, $(subst /,_, $(ALL_PLATFORMS)))

# Used to track state in hidden files.
DOTFILE_IMAGE = $(subst /,_,$(IMAGE))-$(OS_ARCH_TAG)

container: .container-$(DOTFILE_IMAGE) container-name
.container-$(DOTFILE_IMAGE): Dockerfile.in .buildx-initialized
	sed                                   \
	    -e 's|{ARG_NAME}|$(NAME)|g'       \
	    -e 's|{ARG_ARCH}|$(ARCH)|g'       \
	    -e 's|{ARG_OS}|$(OS)|g'           \
	    -e 's|{ARG_VERSION}|$(VERSION)|g' \
	    Dockerfile.in > .dockerfile-$(OS)_$(ARCH)
	docker buildx build              \
	    --builder thockin            \
	    --progress=plain             \
	    --load                       \
	    --platform "$(OS)/$(ARCH)"   \
	    -t $(IMAGE):$(OS_ARCH_TAG)   \
	    -f .dockerfile-$(OS)_$(ARCH) \
	    .
	docker images -q $(IMAGE):$(OS_ARCH_TAG) > $@

container-name:
	echo "container: $(IMAGE):$(OS_ARCH_TAG)"
	echo

push: .push-$(DOTFILE_IMAGE) push-name
.push-$(DOTFILE_IMAGE): .container-$(DOTFILE_IMAGE)
	docker push $(IMAGE):$(OS_ARCH_TAG)
	docker images -q $(IMAGE):$(OS_ARCH_TAG) > $@

push-name:
	echo "pushed: $(IMAGE):$(OS_ARCH_TAG)"
	echo

# This depends on github.com/estesp/manifest-tool/v2/cmd/manifest-tool in $PATH.
manifest-list: all-push
	echo "manifest-list: $(REGISTRY)/$(NAME):$(TAG)"
	platforms=$$(echo $(ALL_PLATFORMS) | sed 's/ /,/g'); \
	manifest-tool                                        \
	    push from-args                                   \
	    --platforms "$$platforms"                        \
	    --template $(REGISTRY)/$(NAME):$(TAG)__OS_ARCH   \
	    --target $(REGISTRY)/$(NAME):$(TAG)

# Help set up multi-arch build tools.  This assumes you have the tools
# installed.  If you already have a buildx builder available, you don't need
# this.  See https://medium.com/@artur.klauser/building-multi-architecture-docker-images-with-buildx-27d80f7e2408
# for great context.
.buildx-initialized:
	docker buildx create --name thockin --node thockin-0 >/dev/null
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes >/dev/null
	date > $@

clean:
	rm -rf .container-* .dockerfile-* .push-* .buildx-initialized

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

AOT_ROOT ?= $(CRT_ROOT)/aot

ENABLE_TVM_PLATFORM_ABORT_BACKTRACE = 0
DMLC_CORE=$(TVM_ROOT)/3rdparty/dmlc-core
TOOLCHAIN_PATH=$(shell dirname $(shell which riscv64-unknown-linux-gnu-gcc))/..

CC = clang-16
CXX = clang++-16

TARGET_CFLAGS = --target=riscv64-unknown-linux-gnu -march=rv64gcv -static
RUNNER = spike
RUNNER_OPT = --isa=rv64gcv $(shell which pk)

PKG_CFLAGS = ${PKG_COMPILE_OPTS} ${TARGET_CFLAGS} -O2 \
	-I$(build_dir)/../include \
	-I$(CODEGEN_ROOT)/host/include \
	-include $(CODEGEN_ROOT)/host/include/tvmgen_default.h \
	-isystem$(STANDALONE_CRT_DIR)/include \
	--sysroot=$(TOOLCHAIN_PATH)/sysroot \
	--gcc-toolchain=$(TOOLCHAIN_PATH)

$(ifeq VERBOSE,1)
QUIET ?=
$(else)
QUIET ?= @
$(endif)

aot_test_runner: $(build_dir)/aot_test_runner

c_source_libs = $(wildcard $(build_dir)/../codegen/host/src/*.c)
cc_source_libs = $(wildcard $(build_dir)/../codegen/host/src/*.cc)
c_lib_objs = $(addprefix $(build_dir)/, $(notdir $(c_source_libs:.c=.o)))
cc_lib_objs = $(cc_source_libs:.cc=.o)

$(build_dir)/aot_test_runner: $(build_dir)/test.c $(c_lib_objs) $(cc_lib_objs) $(build_dir)/stack_allocator.o $(build_dir)/crt_backend_api.o
	$(QUIET)mkdir -p $(@D)
	$(QUIET)$(CC) $(CFLAGS) $(PKG_CFLAGS) -o $@ $^ $(PKG_LDFLAGS) $(BACKTRACE_LDFLAGS) $(BACKTRACE_CFLAGS) -lm

$(build_dir)/%.o: $(build_dir)/../codegen/host/src/%.c
	$(QUIET)mkdir -p $(@D)
	$(QUIET)$(CC) $(CFLAGS) -c $(PKG_CFLAGS) -o $@ $< $(BACKTRACE_CFLAGS)

$(build_dir)/%.o: $(build_dir)/../codegen/host/src/%.cc
	$(QUIET)mkdir -p $(@D)
	$(QUIET)$(CXX) $(CFLAGS) -c $(PKG_CFLAGS) -o $@ $< $(BACKTRACE_CFLAGS)

$(build_dir)/stack_allocator.o: $(STANDALONE_CRT_DIR)/src/runtime/crt/memory/stack_allocator.c
	$(QUIET)mkdir -p $(@D)
	$(QUIET)$(CC) $(CFLAGS) -c $(PKG_CFLAGS) -o $@ $^ $(BACKTRACE_CFLAGS)

$(build_dir)/crt_backend_api.o: $(STANDALONE_CRT_DIR)/src/runtime/crt/common/crt_backend_api.c
	$(QUIET)mkdir -p $(@D)
	$(QUIET)$(CC) $(CFLAGS) -c $(PKG_CFLAGS) -o $@ $^ $(BACKTRACE_CFLAGS)

clean:
	$(QUIET)rm -rf $(build_dir)/crt
cleanall:
	$(QUIET)rm -rf $(build_dir)

run: $(build_dir)/aot_test_runner
	$(RUNNER) $(RUNNER_OPT) $(build_dir)/aot_test_runner

# # Don't define implicit rules; they tend to match on logical target names that aren't targets (i.e. bundle_static)
.SUFFIXES:

.DEFAULT: aot_test_runner

.PHONY: run

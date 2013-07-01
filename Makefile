
SRCDIR := ./Source/
SRCFILES := main.m AppController.m MediaView.m PresentationController.m VideoLayer.m VideoRenderer.m
FRAMEWORKS := IOKit OpenGL QuartzCore Cocoa
EXECUTABLE := mps
OBJDIR := ./obj

ARCH_FLAGS := -arch x86_64
CFLAGS := -W -Wall -Wno-unused-parameter -x objective-c -std=gnu99 -fobjc-arc -fno-strict-aliasing -O2

LIB := $(patsubst %,-framework %,$(notdir $(FRAMEWORKS)))
OBJS += $(patsubst %.m,$(OBJDIR)/%.m.o,$(notdir $(SRCFILES)))

$(OBJDIR)/%.m.o: $(SRCDIR)%.m
	clang $(CFLAGS) $(ARCH_FLAGS) -o $@ -c $<

$(EXECUTABLE): makedirectories $(OBJS) Makefile
	clang $(ARCH_FLAGS) -o $@ $(OBJS) $(LIB)

makedirectories:
	mkdir -p $(OBJDIR)

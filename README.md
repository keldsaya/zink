# ZINK
**Z**INK **I**s **N**ot **K**Build

## What?
ZINK — C language build System like KBuild

## Philosophy
ZINK - Chemistry Element Zn - Zinc. Is system zincify project to comfortable build system, without touching the code

## Using

### Zbuild file is entry point

---

```Bash
git clone https://github.com/keldsaya/zink.git
cd zink
make
make run
```

---

### Struct
```
your-project/
  Makefile
  Zbuild # obj-y += src/ \ hostprogs += tools/
  Zconfig
  tools/
    Makefile # hostprogs += mconfig/
    mconfig/
      Makefile # hostprogs += mconfig \ hostobjs += main.o
      ...
  scripts/
    zconfig.sh
  include/
    config.h # generating
  src/
    Makefile # obj-y += main.o
    main.o
```

---

### Load to your project
```Bash
# clone Zinc
git clone https://github.com/keldsaya/zink.git

# copy system
cp -r zink/tools project
cp -r zink/scripts project
cp zink/Zbuild project
cp zink/Zconfig project
cp zink/Makefile project
cd project
```

---

### Sub-Makefiles
```Makefile
obj-y += dir/ # sub directory
obj-y += file.o # always comliping
obj-$(CONFIG_XYZ) += feature.o # if =y then enabling to compile
hostobj-y += main.o # host program objects
hostprogs-y += elf # host program
```

---

### Editing config
```Makefile
vim Zconfig # add/remove config
make mconfig # open config menu
```

---

### Zconfig
```
menu Sample

config SAMPLE
  bool "Sample feature"
  default y
  help
    Sample

endmenu
```

---

### Specifical Flags
Edit `local.mk`

```Makefile
LDFLAGS += -lraylib -lm
```

## mconfig

### Starting

```Bash
make mconfig
```

### Keys

| Key | Action |
|-----|--------|
| `j` / `↓` | Move cursor down |
| `k` / `↑` | Move cursor up |
| `Enter` | Toggle boolean / Enter submenu / Edit string |
| `Esc` | Go back to parent menu / Cancel command mode |
| `Space` | Toggle boolean |
| `:` | Enter command mode |
| `:q` | Quit without saving |
| `:w` | Save `.config` |
| `:wq` | Save `.config` and quit |
| `:r` | Reload `.config` (discard changes) |

#!/bin/bash

CONFIG_FILE="${1:-.config}"
OUTPUT="build/generated/objs.mk"

declare -A CONFIG
if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r k v; do
    [[ "$k" =~ ^#.*$ ]] && continue
    [[ -z "$k" ]] && continue
    CONFIG["$k"]="$v"
  done < "$CONFIG_FILE"
fi

mkdir -p "$(dirname "$OUTPUT")"
> "$OUTPUT"

add_line() {
  echo "$1" >> "$OUTPUT"
}

parse_makefile() {
  local mf="$1"
  local dir
  dir=$(dirname "$mf")
  dir="${dir#./}"
  [[ "$dir" == "." ]] && dir=""

  while IFS= read -r line; do
    # obj-y += file.o
    if [[ "$line" =~ ^obj-y[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      for item in ${BASH_REMATCH[1]}; do
        if [[ "$item" =~ /$ ]]; then
          local subdir="${item%/}"
          local subpath
          if [[ -n "$dir" ]]; then
            subpath="${dir}/${subdir}/Makefile"
          else
            subpath="${subdir}/Makefile"
          fi
          if [[ -f "$subpath" ]]; then
            parse_makefile "$subpath"
          fi
        else
          if [[ -n "$dir" ]]; then
            add_line "OBJS += build/${dir}/${item%.o}.o"
          else
            add_line "OBJS += build/${item%.o}.o"
          fi
        fi
      done
    fi

    # obj-$(CONFIG_XYZ) += file.o
    if [[ "$line" =~ ^obj-\$\(CONFIG_([a-zA-Z0-9_]+)\)[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      cfg_name="CONFIG_${BASH_REMATCH[1]}"
      items="${BASH_REMATCH[2]}"

      if [[ "${CONFIG[$cfg_name]}" == "y" ]]; then
        for item in $items; do
          if [[ "$item" =~ /$ ]]; then
            local subdir="${item%/}"
            local subpath
            if [[ -n "$dir" ]]; then
              subpath="${dir}/${subdir}/Makefile"
            else
              subpath="${subdir}/Makefile"
            fi
            if [[ -f "$subpath" ]]; then
              parse_makefile "$subpath"
            fi
          else
            if [[ -n "$dir" ]]; then
              add_line "OBJS += build/${dir}/${item%.o}.o"
            else
              add_line "OBJS += build/${item%.o}.o"
            fi
          fi
        done
      fi
    fi

    # hostobj-y += file.o
    if [[ "$line" =~ ^hostobj-y[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      for item in ${BASH_REMATCH[1]}; do
        if [[ ! "$item" =~ /$ ]] && [[ "$item" =~ \.o$ ]]; then
          if [[ -n "$dir" ]]; then
            add_line "HOSTOBJS += build/${dir}/${item%.o}.host.o"
          else
            add_line "HOSTOBJS += build/${item%.o}.host.o"
          fi
        fi
      done
    fi

    # hostprog-y += dir/
    if [[ "$line" =~ ^hostprog-y[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      for item in ${BASH_REMATCH[1]}; do
        if [[ "$item" =~ /$ ]]; then
          local subdir="${item%/}"
          local subpath
          if [[ -n "$dir" ]]; then
            subpath="${dir}/${subdir}/Makefile"
          else
            subpath="${subdir}/Makefile"
          fi
          if [[ -f "$subpath" ]]; then
            parse_makefile "$subpath"
          fi
        else
          if [[ -n "$dir" ]]; then
            add_line "HOSTPROGS += build/${dir}/$item"
          else
            add_line "HOSTPROGS += build/$item"
          fi
        fi
      done
    fi
  done < "$mf"
}

parse_makefile "Zbuild"

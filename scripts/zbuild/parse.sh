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

while IFS= read -r mf; do
  dir=$(dirname "$mf")
  dir="${dir#./}"
  [[ "$dir" == "." ]] && dir=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^obj-y[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      for item in ${BASH_REMATCH[1]}; do
        if [[ ! "$item" =~ /$ ]]; then
          add_line "OBJS += build/${dir}/${item%.o}.o"
        fi
      done
    fi

    if [[ "$line" =~ ^obj-\$\(CONFIG_([a-zA-Z0-9_]+)\)[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      cfg_name="CONFIG_${BASH_REMATCH[1]}"
      items="${BASH_REMATCH[2]}"

      if [[ "${CONFIG[$cfg_name]}" == "y" ]]; then
        for item in $items; do
          if [[ ! "$item" =~ /$ ]]; then
            add_line "OBJS += build/${dir}/${item%.o}.o"
          fi
        done
      fi
    fi

    if [[ "$line" =~ ^hostobj-y[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      for item in ${BASH_REMATCH[1]}; do
        if [[ ! "$item" =~ /$ ]] && [[ "$item" =~ \.o$ ]]; then
          add_line "HOSTOBJS += build/${dir}/${item%.o}.host.o"
        fi
      done
    fi

    if [[ "$line" =~ ^hostprog-y[[:space:]]*\+\=[[:space:]]*(.+)$ ]]; then
      for item in ${BASH_REMATCH[1]}; do
        if [[ ! "$item" =~ /$ ]]; then
          add_line "HOSTPROGS += build/${dir}/$item"
        fi
      done
    fi
  done < "$mf"
done < <(find . -name "Makefile" -type f | grep -v "build/")

#echo "Generated: $(wc -l < "$OUTPUT") entries" >&2

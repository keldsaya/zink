#!/bin/sh

CONFIG_OUT=".config"
HEADER_OUT="include/config.h"

generate_defconfig() {
  echo "# Auto-generated"
  echo ""

  tmp_config=$(mktemp)

  awk '
  BEGIN {
    in_config = 0
    config_name = ""
    config_type = ""
    config_default = ""
  }

  /^[[:space:]]*config/ {
    if (in_config && config_name != "") {
      output_config()
    }
    in_config = 1
    config_name = $2
    config_type = ""
    config_default = ""
  }

  /^[[:space:]]*bool/ {
    config_type = "bool"
    config_default = "n"
  }

  /^[[:space:]]*string/ {
    config_type = "string"
    config_default = ""
  }

  /^[[:space:]]*default/ {
    val = $2
    if (config_type == "bool") {
      config_default = (val == "y" ? "y" : "n")
    } else {
      gsub(/"/, "", val)
      config_default = val
    }
  }

  END {
    if (in_config && config_name != "") {
      output_config()
    }
  }

  function output_config() {
    if (config_type == "bool") {
      if (config_default == "y") {
        print "CONFIG_" config_name "=y"
      } else {
        print "# CONFIG_" config_name " is not set"
      }
    } else if (config_type == "string") {
      print "CONFIG_" config_name "=\"" config_default "\""
    }
  }
  ' Zconfig > "$tmp_config"

  cat "$tmp_config" > "$CONFIG_OUT"
  rm -f "$tmp_config"
}

generate_header() {
  mkdir -p include

  echo "/* Auto-generated from .config */"
  echo ""

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      "#"*) continue ;;
    esac

    case "$line" in
      CONFIG_*=*)
        name="${line%%=*}"
        value="${line#*=}"
        value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')

        case "$value" in
          y)
            echo "#define ${name} 1"
            ;;
          n)
            echo "/* ${name} is not set */"
            ;;
          *)
            escaped=$(echo "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')
            echo "#define ${name} \"${escaped}\""
            ;;
        esac
        ;;
    esac
  done < "$CONFIG_OUT"
}


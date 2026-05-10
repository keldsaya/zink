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

case "$1" in
  --def)
    { echo "# Auto-generated"; echo ""; generate_defconfig; } > "$CONFIG_OUT"
    echo "  GEN   $CONFIG_OUT"
    ;;

  --header)
    if [ -f "$CONFIG_OUT" ]; then
      generate_header > "$HEADER_OUT"
      echo "  GEN   $HEADER_OUT"
    else
      echo "Error: $CONFIG_OUT not found. Run '$0 --def' first." >&2
      exit 1
    fi
    ;;

  *)
    echo "Usage:"
    echo "  $0 --def    - Generate default .config from Zconfig"
    echo "  $0 --header - Generate config.h from .config"
    exit 1
    ;;
esac

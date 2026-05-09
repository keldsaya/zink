#!/bin/sh

CONFIG_OUT=".config"
HEADER_OUT="include/config.h"

generate_defconfig() {
  echo "# Automatically generated from Zconfig"

  current_config=""
  current_type=""
  default_value=""

  while IFS= read -r line; do
    # Remove leading whitespace only
    trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')

    # Skip empty lines and comments
    [ -z "$trimmed" ] && continue

    # Check if line starts with comment
    case "$trimmed" in
      "#"*) continue ;;
    esac

    case "$trimmed" in
      config\ *)
        # Output previous config if complete
        if [ -n "$current_config" ] && [ -n "$current_type" ]; then
          output_config
        fi
        current_config=$(echo "$trimmed" | awk '{print $2}')
        current_type=""
        default_value=""
        ;;

      bool\ *)
        current_type="bool"
        if [ -z "$default_value" ]; then
          default_value="n"
        fi
        ;;

      string\ *)
        current_type="string"
        if [ -z "$default_value" ]; then
          default_value=""
        fi
        ;;

      default\ *)
        default_value=$(echo "$trimmed" | sed 's/^default[[:space:]]*//')
        default_value=$(echo "$default_value" | sed 's/^"\(.*\)"$/\1/')
        ;;

      depends\ on\ *)
        # Skip depends
        ;;

      help*)
        # Help section - output current config
        if [ -n "$current_config" ] && [ -n "$current_type" ]; then
          output_config
        fi
        # Skip help content
        while IFS= read -r help_line; do
          [ -z "$help_line" ] && break
          case "$help_line" in
            *config\ *|*endmenu*) break ;;
          esac
        done
        ;;

      endmenu*)
        # End of menu - output last config if any
        if [ -n "$current_config" ] && [ -n "$current_type" ]; then
          output_config
        fi
        ;;
    esac
  done < Zconfig

  # Output last config if any
  if [ -n "$current_config" ] && [ -n "$current_type" ]; then
    output_config
  fi
}

output_config() {
  case "$current_type" in
    bool)
      if [ "$default_value" = "y" ]; then
        echo "CONFIG_${current_config}=y"
      else
        echo "# CONFIG_${current_config} is not set"
      fi
      ;;
    string)
      if [ -z "$default_value" ]; then
        echo "CONFIG_${current_config}=\"\""
      else
        echo "CONFIG_${current_config}=\"${default_value}\""
      fi
      ;;
  esac

  current_config=""
  current_type=""
  default_value=""
}

generate_header() {
  mkdir -p include

  echo "/* Auto-generated from .config */"
  echo ""

  while IFS= read -r line; do
    # Skip comments and empty lines
    [ -z "$line" ] && continue

    case "$line" in
      "#"*) continue ;;
    esac

    # Check if it's a CONFIG_ line
    case "$line" in
      CONFIG_*=*)
        name="${line%%=*}"
        value="${line#*=}"
        # Remove quotes from value if present
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
    generate_defconfig > "$CONFIG_OUT"
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

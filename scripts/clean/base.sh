#!/bin/bash

clean_dir() {
  local build_dir="build"

  if [[ ! -d "$build_dir" ]]; then
    return 0
  fi

  find "$build_dir" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    local dir_name="${dir#$build_dir/}"
    scripts/log.sh "CLEAN" "$dir_name/"
    rm -rf "${dir:?}"
  done
}

clean_file() {
  local build_dir="build"
  local target_file="$1"

  if [[ -z "$target_file" ]]; then
    return 1
  fi

  local clean_path="$target_file"
  
  if [[ "$target_file" == "$build_dir/"* ]]; then
    clean_path="${target_file#$build_dir/}"
  fi
  
  if [[ -f "$target_file" ]]; then
    scripts/log.sh "CLEAN" "$clean_path"
    rm -f "$target_file"
  fi
}

clean_build_dir() {
  local build_dir="build"

  if [[ -d "$build_dir" ]] && [[ -z "$(ls -A "$build_dir")" ]]; then
    scripts/log.sh "CLEAN" "build/"
    rm -rf "$build_dir"
  fi
}

clean_dir

if [[ -n "$1" ]]; then
  clean_file "$1"
fi

clean_build_dir

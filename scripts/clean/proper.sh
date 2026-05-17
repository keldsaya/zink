#!/bin/bash

source scripts/clean/base.sh

clean_file ".config"
clean_file "include/config.h"
clean_file "include/version.h"


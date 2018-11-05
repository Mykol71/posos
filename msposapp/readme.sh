#!/bin/bash

clear
cat ./bin/*_* | grep "^#" | grep -v bash | sed -e 's/^#//g'

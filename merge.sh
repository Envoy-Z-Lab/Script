#!/bin/bash
sed -i -E \
  -e 's/sdm660-common/lavender/g' \
  -e '/^Change-Id:/d' \
  -e '/^Signed-off-by:/d' "$1"

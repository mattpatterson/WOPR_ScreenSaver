#!/bin/zsh
# Downloads the Natural Earth 110m datasets (public domain) and regenerates
# Sources/MapData.swift. Only needed if you want to change the map data;
# the generated MapData.swift is already committed.
set -e
cd "${0:A:h}/.."
mkdir -p data_dl
base=https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson
for f in ne_110m_coastline ne_110m_lakes ne_110m_admin_0_countries; do
  curl -sSL -o data_dl/$f.geojson $base/$f.geojson
done
python3 -I tools/gen_map.py data_dl/ne_110m_coastline.geojson data_dl/ne_110m_lakes.geojson \
  data_dl/ne_110m_admin_0_countries.geojson Sources/MapData.swift

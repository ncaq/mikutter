HOW TO BUILD MIKUTTER APPIMAGE
==============================
Using Docker
------------
### PREREQUISITE
Docker

### USAGE
```bash
docker build -t mikutter-build-appimage . && docker run --rm -v $PWD/volume:/volume -v $(git rev-parse --show-toplevel):/mikutter-src:ro -it mikutter-build-appimage
```

ビルドに成功すると`./volume`以下に`mikutter-*.AppImage`が生成されているはず．

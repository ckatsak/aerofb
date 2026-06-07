# Bootable rootfs Images

## Build

### Image for single bench

Change into this directory, and select a bench; e.g.:
```console
# BENCH=cnn_serving_geol
```

#### Manually

```console
# TAG=0.0.3 BENCH=$BENCH ./build_rootfs.sh
```

#### Via `make`

```console
# make TAG=0.0.3 $BENCH
```

### Debug mode

Rootfs images can be built in "debug mode" by setting the `DEBUG` environment
variable to `true`:

#### Manually

```console
# DEBUG=true TAG=0.0.3 BENCH=$BENCH ./build_rootfs.sh
```

#### Via `make`

```console
$ make TAG=0.0.3 image_rotate_debug
```

### All rootfs images

Change into repository's root directory, and:
```console
# make bootable_images
```

> [!NOTE]
> Currently, there is no way to automatically build _all_ rootfs images in debug
> mode; they can only be built one-by-one, manually.


## Distribution per Bench

|      **bench**     |      **distro**      |
|:------------------:|:--------------------:|
|     `chameleon`    |     alpine 3.17.3    |
| `cnn_serving_geol` |    ubuntu 20.04.5    |
|    `helloworld`    |     alpine 3.17.3    |
|   `image_rotate`   |     alpine 3.17.3    |
|    `json_serdes`   |     alpine 3.17.3    |
|    `lr_serving`    |     alpine 3.17.3    |
|    `lr_training`   |     alpine 3.17.3    |
|     `matmul_fb`    |     alpine 3.17.3    |
|  `new_lr_serving`  |     alpine 3.17.3    |
|  `new_lr_training` |     alpine 3.17.3    |
|       `pyaes`      |     alpine 3.17.3    |
|    `rnn_serving`   | debian 11 (bullseye) |
| `video_processing` | debian 11 (bullseye) |

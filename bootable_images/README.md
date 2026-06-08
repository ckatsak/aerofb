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

#
# ckatsak, Sun Jun  7 06:28:24 PM EEST 2026
#
# Pure-Python port of `pyptpsync`'s C extension:
#   https://github.com/ckatsak/pyptpsync/
#
# - Linux-only
# - Requires Python >= 3.7 for `*_ns` clock APIs.
# - Works on `aarch64`; should be `amd64`-compatible as well.
#   (The hardcoded ioctl numbers construction is probably NOT _universally_
#   portable. Dropping `check_validity` should probably further minimize
#   the surface of ABI compatibility required.)

from __future__ import annotations

import fcntl
import os
import time
from typing import Union


DEFAULT_PTP_DEV_PATH = "/dev/ptp0"

# Same Linux dynamic-clock encoding used by clock_gettime(3).
# See FD_TO_CLOCKID in the original C extension / Linux man page.
CLOCKFD = 3


def fd_to_clockid(fd: int) -> int:
    return ((~fd) << 3) | CLOCKFD


def clockid_to_fd(clkid: int) -> int:
    return ~((clkid) >> 3)


# Linux ioctl encoding, enough for PTP_CLOCK_GETCAPS.
# This matches asm-generic ioctl layout used by x86_64/aarch64 Linux.
_IOC_NRBITS = 8
_IOC_TYPEBITS = 8
_IOC_SIZEBITS = 14

_IOC_NRSHIFT = 0
_IOC_TYPESHIFT = _IOC_NRSHIFT + _IOC_NRBITS
_IOC_SIZESHIFT = _IOC_TYPESHIFT + _IOC_TYPEBITS
_IOC_DIRSHIFT = _IOC_SIZESHIFT + _IOC_SIZEBITS

_IOC_READ = 2


def _IOC(direction: int, type_: int, nr: int, size: int) -> int:
    return (
        (direction << _IOC_DIRSHIFT)
        | (type_ << _IOC_TYPESHIFT)
        | (nr << _IOC_NRSHIFT)
        | (size << _IOC_SIZESHIFT)
    )


def _IOR(type_: int, nr: int, size: int) -> int:
    return _IOC(_IOC_READ, type_, nr, size)


# From linux/uapi/linux/ptp_clock.h:
#   #define PTP_CLK_MAGIC '='
#   struct ptp_clock_caps { int fields[20]; };
#   #define PTP_CLOCK_GETCAPS _IOR(PTP_CLK_MAGIC, 1, struct ptp_clock_caps)
#
# Current struct ptp_clock_caps is 20 x 4-byte ints = 80 bytes.
PTP_CLK_MAGIC = ord("=")
PTP_CLOCK_CAPS_SIZE = 80
PTP_CLOCK_GETCAPS = _IOR(PTP_CLK_MAGIC, 1, PTP_CLOCK_CAPS_SIZE)


PathLike = Union[str, bytes, os.PathLike]


def clock_to_sys(
    path: PathLike = DEFAULT_PTP_DEV_PATH,
    check_validity: bool = False,
) -> None:
    """
    Read time from a Linux PTP clock device and set CLOCK_REALTIME to it.

    This is equivalent to pyptpsync's C extension:

        ptpsync.clock_to_sys(path="/dev/ptp0", check_validity=False)

    Requirements:
      - Linux PTP clock device, e.g. /dev/ptp0
      - permission to open the device
      - CAP_SYS_TIME / sufficient privilege to set CLOCK_REALTIME
    """
    fd = os.open(os.fspath(path), os.O_RDONLY)

    try:
        clkid = fd_to_clockid(fd)

        if check_validity:
            # We do not inspect the returned capabilities; this mirrors the
            # C extension, which only checks whether the ioctl succeeds.
            caps = bytearray(PTP_CLOCK_CAPS_SIZE)
            try:
                fcntl.ioctl(clockid_to_fd(clkid), PTP_CLOCK_GETCAPS, caps, True)
            except OSError as e:
                raise RuntimeError("Invalid clock id") from e

        now_ns = time.clock_gettime_ns(clkid)
        time.clock_settime_ns(time.CLOCK_REALTIME, now_ns)

    finally:
        os.close(fd)


__all__ = ["clock_to_sys"]

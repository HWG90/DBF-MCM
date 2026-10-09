"""Bounded multi-type Stingray archive replacement; preserves unrelated bytes."""
from __future__ import annotations
import struct
from dataclasses import dataclass


@dataclass(frozen=True)
class Resource:
    name: int
    kind: int
    offset: int
    size: int
    record: int


def resources(data: bytes) -> list[Resource]:
    if len(data) < 104 or struct.unpack_from("<I", data)[0] != 0xF0000011:
        raise ValueError("Invalid Stingray archive")
    types, count = struct.unpack_from("<II", data, 4)
    start = 72 + types * 32
    if not 1 <= types <= 1024 or not 1 <= count <= 100000 or start + count * 80 > len(data):
        raise ValueError("Invalid archive table bounds")
    result = []
    for index in range(count):
        record = start + index * 80
        name, kind, offset = struct.unpack_from("<3Q", data, record)
        size = struct.unpack_from("<I", data, record + 56)[0]
        if size and (offset < start + count * 80 or offset + size > len(data)):
            raise ValueError("Invalid resource bounds")
        result.append(Resource(name, kind, offset, size, record))
    return result


def replace(data: bytes, name: int, body: bytes) -> bytes:
    rows = resources(data)
    matches = [row for row in rows if row.name == name]
    if len(matches) != 1 or not matches[0].size:
        raise ValueError("Replacement requires one nonempty resource")
    target = matches[0]
    end = target.offset + target.size
    for row in rows:
        if row != target and row.size and row.offset < end and row.offset + row.size > target.offset:
            raise ValueError("Replacement overlaps another resource")
    delta = len(body) - target.size
    output = bytearray(data[:target.offset] + body + data[end:])
    struct.pack_into("<I", output, target.record + 56, len(body))
    for row in rows:
        if row != target and row.size and row.offset >= end:
            struct.pack_into("<Q", output, row.record + 16, row.offset + delta)
    # Some single-type archives record their own byte length here; multi-type
    # packages can carry another logical size, which must remain untouched.
    if struct.unpack_from("<Q", data, 32)[0] == len(data):
        struct.pack_into("<Q", output, 32, len(output))
    checked = resources(output)
    for before, after in zip(rows, checked):
        if before.name != after.name or before.kind != after.kind:
            raise ValueError("Resource identity changed")
        expected = body if before == target else data[before.offset:before.offset + before.size]
        if output[after.offset:after.offset + after.size] != expected:
            raise ValueError("Unrelated resource content changed")
    return bytes(output)


def first_language(data: bytes) -> dict[int, str]:
    if len(data) < 12:
        raise ValueError("Invalid strings resource")
    _, languages, count = struct.unpack_from("<III", data)
    start = 12 + languages * 4
    offsets = start + count * 4
    table_end = offsets + languages * count * 4
    if not 1 <= languages <= 64 or not 1 <= count <= 100000 or table_end > len(data):
        raise ValueError("Invalid strings table bounds")
    result = {}
    for index in range(count):
        key = struct.unpack_from("<I", data, start + index * 4)[0]
        at = struct.unpack_from("<I", data, offsets + index * 4)[0]
        end = data.find(b"\0", at)
        if at < table_end or end < at:
            raise ValueError("Invalid localized string bounds")
        result[key] = data[at:end].decode("utf-8")
    return result

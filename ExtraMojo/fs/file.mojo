"""
Helper functions for working with files
"""
import math
from algorithm import vectorize
from collections import Optional
from memory import Span, UnsafePointer, memcpy
from sys.info import simdwidthof
from tensor import Tensor


from ExtraMojo.bstr.bstr import (
    find_chr_all_occurrences,
)
from ExtraMojo.bstr.memchr import memchr_wide


alias NEW_LINE = 10
alias SIMD_U8_WIDTH: Int = simdwidthof[DType.uint8]()
# 128 KiB: http://git.savannah.gnu.org/gitweb/?p=coreutils.git;a=blob;f=src/ioblksize.h;h=266c209f48fc07cb4527139a2548b6398b75f740;hb=HEAD#l23
alias BUF_SIZE: Int = 1024 * 128


fn read_lines(
    path: String, buf_size: Int = BUF_SIZE
) raises -> List[List[UInt8]]:
    """
    Read all the lines in the file and return them as a [`DynamicVector`] of [`Tensor[DType.int8]`].
    """
    # TODO: make this an iterator
    var fh = open(path, "r")
    var result = List[List[UInt8]]()
    var file_pos = 0

    while True:
        _ = fh.seek(file_pos)
        var buffer = fh.read_bytes(buf_size)
        var newlines = find_chr_all_occurrences(buffer, NEW_LINE)
        var start = 0
        for i in range(0, len(newlines)):
            var newline = newlines[i]
            result.append(buffer[start:newline])
            # result.append(slice_tensor(buffer, start, newline))
            start = newline + 1

        if len(buffer) < BUF_SIZE:
            break
        file_pos += start
    return result


fn for_each_line[
    func: fn (Span[UInt8], Int, Int) capturing -> None
](path: String, buf_size: Int = BUF_SIZE) raises:
    """
    Call the provided callback on each line.

    The callback will be given a buffer, and the [start, end) of where the line is in that buffer.
    """
    var fh = open(path, "r")
    # var result = List[Tensor[DType.int8]]()
    var file_pos = 0

    while True:
        _ = fh.seek(file_pos)
        var buffer = fh.read_bytes(buf_size)
        var buffer_index = 0

        while True:
            var newline = memchr_wide(buffer, NEW_LINE, buffer_index)
            if newline == -1:
                break

            func(buffer, buffer_index, newline)
            buffer_index = newline + 1

        file_pos += buffer_index
        if len(buffer) < BUF_SIZE:
            break


@always_inline
fn get_next_line[
    is_mutable: Bool, //, origin: Origin[is_mutable]
](buffer: Span[UInt8, origin], start: Int) -> Span[UInt8, origin]:
    """Function to get the next line using either SIMD instruction (default) or iteratively.
    """

    var in_start = start
    while buffer[in_start] == NEW_LINE:  # Skip leading \n
        in_start += 1
        if in_start >= len(buffer):
            return buffer[0:0]

    var next_line_pos = memchr_wide(buffer, NEW_LINE, in_start)
    if next_line_pos == -1:
        next_line_pos = len(
            buffer
        )  # If no line separator found, return the reminder of the string, behavior subject to change
    return buffer[in_start:next_line_pos]


struct FileReader:
    """
    WIP FileReader for readying lines and bytes from a file in a buffered way.
    """

    var fh: FileHandle
    var file_offset: Int
    var buffer_offset: Int
    var buffer: UnsafePointer[UInt8]
    var buffer_size: Int
    var buffer_len: Int

    fn __init__(
        out self, owned fh: FileHandle, buffer_size: Int = BUF_SIZE
    ) raises:
        self.fh = fh^
        self.file_offset = 0
        self.buffer_offset = 0
        self.buffer_size = buffer_size
        self.buffer = UnsafePointer[UInt8].alloc(self.buffer_size)
        self.buffer_len = 0
        _ = self._fill_buffer()

    fn __del__(owned self):
        try:
            self.fh.close()
        except:
            pass
        self.buffer.free()

    fn __enter__(owned self) -> Self:
        return self^

    fn __moveinit__(out self, owned existing: Self):
        self.fh = existing.fh^
        self.file_offset = existing.file_offset
        self.buffer_offset = existing.buffer_offset
        self.buffer = existing.buffer
        self.buffer_size = existing.buffer_size
        self.buffer_len = existing.buffer_len

    fn read_until(
        mut self, mut line_buffer: List[UInt8], char: UInt = NEW_LINE
    ) raises -> Int:
        """
        Fill the given `line_buffer` until the given `char` is hit.

        This does not include the `char`. The input vector is cleared before reading into it.
        """
        if self.buffer_len == 0:
            return 0

        # Find the next newline in the buffer
        var newline_index = memchr_wide(
            Span[UInt8, __origin_of(self)](
                ptr=self.buffer, length=self.buffer_len
            ),
            NEW_LINE,
            self.buffer_offset,
        )

        # Try to refill the buffer
        if newline_index == -1:
            self.file_offset += self.buffer_offset
            var bytes_filled = self._fill_buffer()
            if bytes_filled == 0:
                # This seems dubious. If we haven't found a newline in the buffer, just return 0, which will also indicate EOF
                return 0
            newline_index = memchr_wide(
                Span[UInt8, __origin_of(self)](
                    ptr=self.buffer, length=self.buffer_len
                ),
                char,
                self.buffer_offset,
            )
            if newline_index == -1:
                return 0

        # Copy the line into the provided buffer
        line_buffer.clear()
        var size = newline_index - self.buffer_offset
        line_buffer.reserve(size)
        var line_ptr = line_buffer.unsafe_ptr()
        memcpy(line_ptr, self.buffer.offset(self.buffer_offset), size)
        # TODO: is there a better way to do this?
        line_buffer.size = size

        # Advance our position in our buffer
        self.buffer_offset = newline_index + 1

        return len(line_buffer)

    fn _fill_buffer(mut self) raises -> Int:
        # Copy the bytes at the end of the buffer to the front
        var keep = self.buffer_len - self.buffer_offset
        memcpy(self.buffer, self.buffer.offset(self.buffer_offset), keep)

        # Now fill from there to end
        var tmp_ptr = self.buffer.offset(keep)
        var bytes_read = self.fh.read(tmp_ptr, self.buffer_size - keep)
        self.buffer_len = bytes_read.__int__() + keep
        self.buffer_offset = 0
        return self.buffer_len


# TODO: move this to a different location


struct BufferedWriter:
    var fh: FileHandle
    var buffer: List[UInt8]
    var buffer_capacity: Int
    var buffer_len: Int

    fn __init__(
        out self, owned fh: FileHandle, buffer_capacity: Int = BUF_SIZE
    ) raises:
        self.fh = fh^
        self.buffer = List[UInt8](capacity=buffer_capacity)
        self.buffer_capacity = buffer_capacity
        self.buffer_len = 0

    fn __del__(owned self):
        try:
            self.fh.close()
        except:
            pass

    fn __enter_(owned self) -> Self:
        return self^

    fn __moveinit__(out self, owned existing: Self):
        self.fh = existing.fh^
        self.buffer = existing.buffer^
        self.buffer_capacity = existing.buffer_capacity
        self.buffer_len = existing.buffer_len

    fn close(mut self) raises:
        self.flush()
        self.fh.close()

    fn write_bytes(mut self, bytes: Span[UInt8]) raises:
        var b = bytes
        while True:
            var end = min(self.buffer_capacity - self.buffer_len, len(b))

            var to_copy = b[:end]
            memcpy(
                self.buffer.unsafe_ptr().offset(self.buffer_len),
                to_copy.unsafe_ptr(),
                len(to_copy),
            )
            self.buffer.size += len(to_copy)
            self.buffer_len += len(to_copy)
            if len(to_copy) == len(b):
                break
            else:
                self.flush()
            b = b[end:]

    fn flush(mut self) raises:
        self.fh.write_bytes(Span(self.buffer))
        self.buffer_len = 0
        self.buffer.clear()

"""
Helper functions for working with files
"""
import math
from algorithm import vectorize
from collections import Optional
from sys.info import simdwidthof
from tensor import Tensor

from xmojo.tensor.slice import (
    slice_tensor_simd,
    slice_tensor_iter,
    slice_tensor,
)

alias USE_SIMD = True
alias NEW_LINE = 10
alias SIMD_U8_WIDTH: Int = simdwidthof[DType.uint8]()
alias BUF_SIZE: Int = 1024 * 64


@always_inline
fn find_chr_all_occurances[
    T: DType
](in_tensor: Tensor[T], chr: Int) -> List[Int]:
    """
    Find all the occurances of `chr` in the input buffer.
    """
    var holder = List[Int]()

    @parameter
    fn inner[simd_width: Int](size: Int):
        var simd_vec = in_tensor.load[width=simd_width](size)
        var bool_vec = simd_vec == chr
        if bool_vec.reduce_or():
            # TODO: @unroll
            for i in range(len(bool_vec)):
                if bool_vec[i]:
                    holder.append(size + i)

    vectorize[inner, SIMD_U8_WIDTH](in_tensor.num_elements())
    return holder


fn read_lines(
    path: String, buf_size: Int = BUF_SIZE
) raises -> List[Tensor[DType.uint8]]:
    """
    Read all the lines in the file and return them as a [`DynamicVector`] of [`Tensor[DType.int8]`].
    """
    var fh = open(path, "r")
    var result = List[Tensor[DType.uint8]]()
    var file_pos = 0

    while True:
        _ = fh.seek(file_pos)
        var buffer = fh.read_bytes(buf_size)
        var newlines = find_chr_all_occurances(buffer, NEW_LINE)
        var start = 0
        for i in range(0, len(newlines)):
            var newline = newlines[i]
            result.append(slice_tensor(buffer, start, newline))
            start = newline + 1

        if len(buffer) < BUF_SIZE:
            break
        file_pos += start
    return result


fn for_each_line[
    func: fn (Tensor[DType.uint8], Int, Int) capturing -> None
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
            var newline = find_chr_next_occurance_simd(
                buffer, NEW_LINE, buffer_index
            )
            if newline == -1:
                break

            func(buffer, buffer_index, newline)
            buffer_index = newline + 1

        file_pos += buffer_index
        if len(buffer) < BUF_SIZE:
            break


@always_inline
fn arg_true[simd_width: Int](v: SIMD[DType.bool, simd_width]) -> Int:
    for i in range(simd_width):
        if v[i]:
            return i
    return -1


@always_inline
fn find_chr_next_occurance_simd[
    T: DType
](in_tensor: Tensor[T], chr: UInt, start: Int = 0) -> Int:
    """
    Function to find the next occurrence of character using SIMD instruction.
    The function assumes that the tensor is always in-bounds. any bound checks should be in the calling function.
    """
    var tensor_len = in_tensor.num_elements() - start
    var aligned = start + math.align_down(tensor_len, SIMD_U8_WIDTH)

    for s in range(start, aligned, SIMD_U8_WIDTH):
        var v = in_tensor.load[width=SIMD_U8_WIDTH](s)
        var mask = v == chr
        if mask.reduce_or():
            return s + arg_true(mask)

    for i in range(aligned, in_tensor.num_elements()):
        if in_tensor[i] == chr:
            return i

    return -1


@always_inline
fn find_chr_next_occurance_iter[
    T: DType
](in_tensor: Tensor[T], chr: Int, start: Int = 0) -> Int:
    """
    Generic Function to find the next occurance of character Iterativly.
    No overhead for tensors < 1,000 items while being easier to debug.
    """
    for i in range(start, in_tensor.num_elements()):
        if in_tensor[i] == chr:
            return i
    return -1


@always_inline
fn get_next_line[
    T: DType, USE_SIMD: Bool = True
](in_tensor: Tensor[T], start: Int) -> Tensor[T]:
    """Function to get the next line using either SIMD instruction (default) or iterativly.
    """

    var in_start = start
    while in_tensor[in_start] == NEW_LINE:  # Skip leadin \n
        in_start += 1
        if in_start >= in_tensor.num_elements():
            return Tensor[T](0)

    @parameter
    if USE_SIMD:
        var next_line_pos = find_chr_next_occurance_simd(
            in_tensor, NEW_LINE, in_start
        )
        if next_line_pos == -1:
            next_line_pos = (
                in_tensor.num_elements()
            )  # If no line separator found, return the reminder of the string, behaviour subject to change
        return slice_tensor_simd(in_tensor, in_start, next_line_pos)
    else:
        var next_line_pos = find_chr_next_occurance_iter(
            in_tensor, NEW_LINE, in_start
        )
        if next_line_pos == -1:
            next_line_pos = (
                in_tensor.num_elements()
            )  # If no line separator found, return the reminder of the string, behaviour subject to change
        return slice_tensor_iter(in_tensor, in_start, next_line_pos)


struct FileReader:
    """
    WIP FileReader for readying lines and bytes from a file in a buffered way.
    """

    var fh: FileHandle
    var file_offset: Int
    var buffer_offset: Int
    var buffer: Tensor[DType.uint8]
    var buffer_size: Int

    fn __init__(
        inout self, owned fh: FileHandle, buffer_size: Int = BUF_SIZE
    ) raises:
        var buffer = fh.read_bytes(buffer_size)
        self.fh = fh^
        self.file_offset = 0
        self.buffer_offset = 0
        self.buffer_size = buffer_size
        self.buffer = buffer

    fn read_until(
        inout self, inout line_buffer: List[UInt8], char: UInt = NEW_LINE
    ) raises -> Int:
        """
        Fill the given `line_buffer` until the given `char` is hit.

        This does not include the `char`. The input vector is cleared before reading into it.
        """
        if self.buffer.num_elements() == 0:
            return 0

        # Find the next newline in the buffer
        var newline_index = find_chr_next_occurance_simd(
            self.buffer, NEW_LINE, self.buffer_offset
        )

        # Try to refill the buffer
        if newline_index == -1:
            self.file_offset += self.buffer_offset
            var bytes_filled = self._fill_buffer()
            if bytes_filled == 0:
                return 0
            newline_index = find_chr_next_occurance_simd(
                self.buffer, char, self.buffer_offset
            )
            if newline_index == -1:
                return 0

        # Copy the line into the provided buffer
        line_buffer.clear()
        for i in range(self.buffer_offset, newline_index):
            line_buffer.append(self.buffer[i])

        # Advance our position in our buffer
        self.buffer_offset = newline_index + 1

        return len(line_buffer)

    fn _fill_buffer(inout self) raises -> Int:
        _ = self.fh.seek(self.file_offset)
        self.buffer = self.fh.read_bytes(self.buffer_size)
        self.buffer_offset = 0
        return self.buffer.num_elements()

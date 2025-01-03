import math
from algorithm import vectorize
from collections import Optional
from memory import Span, UnsafePointer
from sys.info import simdwidthof


# TODO: split this all out and create similar abstractions as the Rust bstr crate
# TODO: add an ascii to lower case


alias SIMD_U8_WIDTH: Int = simdwidthof[DType.uint8]()


@always_inline
fn arg_true[simd_width: Int](v: SIMD[DType.bool, simd_width]) -> Int:
    for i in range(simd_width):
        if v[i]:
            return i
    return -1


@always_inline
fn find_chr_all_occurrences(haystack: Span[UInt8], chr: UInt8) -> List[Int]:
    """Find all the occurrences of `chr` in the input buffer."""
    var holder = List[Int]()

    if len(haystack) < SIMD_U8_WIDTH:
        for i in range(0, len(haystack)):
            if haystack[i] == chr:
                holder.append(i)
        return holder

    @parameter
    fn inner[simd_width: Int](offset: Int):
        var simd_vec = haystack.unsafe_ptr().load[width=simd_width](offset)
        var bool_vec = simd_vec == chr
        if bool_vec.reduce_or():
            # TODO: @unroll
            for i in range(len(bool_vec)):
                if bool_vec[i]:
                    holder.append(offset + i)

    vectorize[inner, SIMD_U8_WIDTH](len(haystack))
    return holder


@always_inline
fn find_chr_next_occurrence(
    haystack: Span[UInt8], chr: UInt8, start: Int = 0
) -> Int:
    """
    Function to find the next occurrence of character using SIMD instruction.
    The function assumes that the tensor is always in-bounds. any bound checks should be in the calling function.
    """
    if len(haystack) < SIMD_U8_WIDTH * 3:
        for i in range(start, len(haystack)):
            if haystack[i] == chr:
                return i
        return -1

    var haystack_len = len(haystack) - start
    var aligned = start + math.align_down(haystack_len, SIMD_U8_WIDTH)

    for s in range(start, aligned, SIMD_U8_WIDTH):
        var v = haystack[s:].unsafe_ptr().load[width=SIMD_U8_WIDTH]()
        var mask = v == chr
        if any(mask):
            return s + arg_true(mask)

    for i in range(aligned, len(haystack)):
        if haystack[i] == chr:
            return i

    return -1


alias CAPITAL_A = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("A"))
alias CAPITAL_Z = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("Z"))
alias LOWER_A = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("a"))
alias LOWER_Z = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("z"))
alias ASCII_CASE_MASK = SIMD[DType.uint8, SIMD_U8_WIDTH](
    32
)  # The diff between a and A is just the sixth bit set
alias ZERO = SIMD[DType.uint8, SIMD_U8_WIDTH](0)


@always_inline
fn is_ascii_uppercase(value: UInt8) -> Bool:
    return value >= 65 and value <= 90  # 'A' -> 'Z'


@always_inline
fn is_ascii_lowercase(value: UInt8) -> Bool:
    return value >= 97 and value <= 122  # 'a' -> 'z'


@always_inline
fn to_ascii_lowercase(mut buffer: List[UInt8]):
    """Lowercase all ascii a-zA-Z characters."""
    if len(buffer) < SIMD_U8_WIDTH * 3:
        for i in range(0, len(buffer)):
            buffer[i] |= UInt8(is_ascii_uppercase(buffer[i])) * 32
        return

    var buffer_len = len(buffer)
    var aligned = math.align_down(buffer_len, SIMD_U8_WIDTH)
    var buf = Span(buffer)

    for s in range(0, aligned, SIMD_U8_WIDTH):
        var v = buf[s:].unsafe_ptr().load[width=SIMD_U8_WIDTH]()
        var ge_A = v >= CAPITAL_A
        var le_Z = v <= CAPITAL_Z
        var is_upper = ge_A.__and__(le_Z)
        v |= ASCII_CASE_MASK * is_upper.cast[DType.uint8]()
        buffer.unsafe_ptr().store(s, v)

    for i in range(aligned, len(buffer)):
        buffer[i] |= UInt8(is_ascii_uppercase(buffer[i])) * 32


@always_inline
fn to_ascii_uppercase(mut buffer: List[UInt8]):
    """Uppercase all ascii a-zA-Z characters."""
    if len(buffer) < SIMD_U8_WIDTH * 3:
        for i in range(0, len(buffer)):
            buffer[i] ^= UInt8(is_ascii_lowercase(buffer[i])) * 32
        return

    var buffer_len = len(buffer)
    var aligned = math.align_down(buffer_len, SIMD_U8_WIDTH)
    var buf = Span(buffer)

    for s in range(0, aligned, SIMD_U8_WIDTH):
        var v = buf[s:].unsafe_ptr().load[width=SIMD_U8_WIDTH]()
        var ge_a = v >= LOWER_A
        var le_z = v <= LOWER_Z
        var is_lower = ge_a.__and__(le_z)
        v ^= ASCII_CASE_MASK * is_lower.cast[DType.uint8]()
        buffer.unsafe_ptr().store(s, v)

    for i in range(aligned, len(buffer)):
        buffer[i] ^= UInt8(is_ascii_lowercase(buffer[i])) * 32


fn find(haystack: Span[UInt8], needle: Span[UInt8]) -> Optional[Int]:
    """Look for the substring `needle` in the haystack.

    This returns the index of the start of the first occurrence of needle.
    """
    # TODO: memchr/memmem probably
    # https://github.com/BurntSushi/bstr/blob/master/src/ext_slice.rs#L3094
    # https://github.com/BurntSushi/memchr/blob/master/src/memmem/searcher.rs

    # Naive-ish search. Use our simd accel searcher to find the first char in the needle
    # check for extension, and move forward
    var start = 0
    while start < len(haystack):
        start = find_chr_next_occurrence(haystack, needle[0], start)
        if start == -1:
            return None
        # Try extension
        var matched = True
        for i in range(1, len(needle)):
            if haystack[start + i] != needle[i]:
                matched = False
                break
        if matched:
            return start
        else:
            start = start + 1
    return None


@value
@register_passable
struct _StartEnd:
    var start: Int
    var end: Int


@value
struct SplitIterator[is_mutable: Bool, //, origin: Origin[is_mutable]]:
    var inner: Span[UInt8, origin]
    var split_on: UInt8
    var current: Int
    var len: Int
    var next_split: Optional[_StartEnd]

    fn __init__(out self, to_split: Span[UInt8, origin], split_on: UInt8):
        self.inner = to_split
        self.split_on = split_on
        self.current = 0
        self.len = 1
        self.next_split = None
        self._find_next_split()

    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __len__(read self) -> Int:
        return self.len

    @always_inline
    fn __has_next__(read self) -> Bool:
        return self.__len__() > 0

    fn __next__(mut self) -> Span[UInt8, origin]:
        var ret = self.next_split.value()

        self._find_next_split()
        return self.inner[ret.start : ret.end]

    fn _find_next_split(mut self):
        if self.current >= len(self.inner):
            self.next_split = None
            self.len = 0
            return

        var end = find_chr_next_occurrence(
            self.inner, self.split_on, self.current
        )

        if end != -1:
            self.next_split = _StartEnd(self.current, end)
            self.current = end + 1
        else:
            self.next_split = _StartEnd(self.current, len(self.inner))
            self.current = len(self.inner) + 1

    fn peek(read self) -> Optional[Span[UInt8, origin]]:
        if self.next_split:
            var split = self.next_split.value()
            return self.inner[split.start : split.end]
        else:
            return None

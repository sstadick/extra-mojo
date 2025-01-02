import math
from algorithm import vectorize
from collections import Optional
from memory import Span, UnsafePointer
from sys.info import simdwidthof

<<<<<<< HEAD
from ExtraMojo.bstr.memchr import memchr


# TODO: split this all out and create similar abstractions as the Rust bstr crate
=======

# TODO: split this all out and create similar abstractions as the Rust bstr crate
# TODO: add an ascii to lower case
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))


alias SIMD_U8_WIDTH: Int = simdwidthof[DType.uint8]()


@always_inline
<<<<<<< HEAD
fn find_chr_all_occurrences(haystack: Span[UInt8], chr: UInt8) -> List[Int]:
    """Find all the occurrences of `chr` in the input buffer."""
    var holder = List[Int]()
    # TODO alignment
    # TODO move this to memchr?
=======
fn arg_true[simd_width: Int](v: SIMD[DType.bool, simd_width]) -> Int:
    for i in range(simd_width):
        if v[i]:
            return i
    return -1


@always_inline
fn find_chr_all_occurrences(haystack: Span[UInt8], chr: UInt8) -> List[Int]:
    """Find all the occurrences of `chr` in the input buffer."""
    var holder = List[Int]()
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))

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


<<<<<<< HEAD
alias CAPITAL_A = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("A"))
alias CAPITAL_Z = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("Z"))
alias LOWER_A = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("a"))
alias LOWER_Z = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("z"))
alias ASCII_CASE_MASK = SIMD[DType.uint8, SIMD_U8_WIDTH](
    32
)  # The diff between a and A is just the sixth bit set
=======
@always_inline
fn find_chr_next_occurrence_simd(
    haystack: Span[UInt8], chr: UInt8, start: Int = 0
) -> Int:
    """
    Function to find the next occurrence of character using SIMD instruction.
    The function assumes that the tensor is always in-bounds. any bound checks should be in the calling function.
    """
    if len(haystack) < SIMD_U8_WIDTH:
        for i in range(0, len(haystack)):
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
alias TO_LOWER_DIFF = SIMD[DType.uint8, SIMD_U8_WIDTH](ord("a") - ord("A"))
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))
alias ZERO = SIMD[DType.uint8, SIMD_U8_WIDTH](0)


@always_inline
<<<<<<< HEAD
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

    # Initial unaligned set
    var ptr = buffer.unsafe_ptr()
    var v = ptr.load[width=SIMD_U8_WIDTH]()
    _to_ascii_lowercase_vec(v)
    ptr.store(0, v)

    # Now get an aligned pointer
    var offset = SIMD_U8_WIDTH - (ptr.__int__() & (SIMD_U8_WIDTH - 1))
    var aligned_ptr = ptr.offset(offset)

    # Find the last aligned read possible
    var buffer_len = len(buffer) - offset
    var aligned_end = math.align_down(
        buffer_len, SIMD_U8_WIDTH
    )  # relative to offset

    # Now do aligned reads all through
    for s in range(0, aligned_end, SIMD_U8_WIDTH):
        var v = aligned_ptr.load[width=SIMD_U8_WIDTH](s)
        _to_ascii_lowercase_vec(v)
        aligned_ptr.store(s, v)

    for i in range(aligned_end + offset, len(buffer)):
        buffer[i] |= UInt8(is_ascii_uppercase(buffer[i])) * 32


@always_inline
fn _to_ascii_lowercase_vec(mut v: SIMD[DType.uint8, SIMD_U8_WIDTH]):
    var ge_A = v >= CAPITAL_A
    var le_Z = v <= CAPITAL_Z
    var is_upper = ge_A.__and__(le_Z)
    v |= ASCII_CASE_MASK * is_upper.cast[DType.uint8]()


@always_inline
fn to_ascii_uppercase(mut buffer: List[UInt8]):
    """Uppercase all ascii a-zA-Z characters."""
    if len(buffer) < SIMD_U8_WIDTH * 3:
        for i in range(0, len(buffer)):
            buffer[i] ^= UInt8(is_ascii_lowercase(buffer[i])) * 32
        return

    # Initial unaligned set
    var ptr = buffer.unsafe_ptr()
    var v = ptr.load[width=SIMD_U8_WIDTH]()
    _to_ascii_uppercase_vec(v)
    ptr.store(0, v)

    # Now get an aligned pointer
    var offset = SIMD_U8_WIDTH - (ptr.__int__() & (SIMD_U8_WIDTH - 1))
    var aligned_ptr = ptr.offset(offset)

    # Find the last aligned read possible
    var buffer_len = len(buffer) - offset
    var aligned_end = math.align_down(
        buffer_len, SIMD_U8_WIDTH
    )  # relative to offset

    # Now do aligned reads all through
    for s in range(0, aligned_end, SIMD_U8_WIDTH):
        var v = aligned_ptr.load[width=SIMD_U8_WIDTH](s)
        _to_ascii_uppercase_vec(v)
        aligned_ptr.store(s, v)

    for i in range(aligned_end + offset, len(buffer)):
        buffer[i] ^= UInt8(is_ascii_lowercase(buffer[i])) * 32


@always_inline
fn _to_ascii_uppercase_vec(mut v: SIMD[DType.uint8, SIMD_U8_WIDTH]):
    var ge_a = v >= LOWER_A
    var le_z = v <= LOWER_Z
    var is_lower = ge_a.__and__(le_z)
    v ^= ASCII_CASE_MASK * is_lower.cast[DType.uint8]()
=======
fn to_ascii_lowercase_simd(mut buffer: List[UInt8]):
    """Lowercase all ascii a-zA-Z characters."""
    if len(buffer) < SIMD_U8_WIDTH:
        for i in range(0, len(buffer)):
            var value = buffer[i]
            buffer[i] = (
                value + 32 if value >= ord("A") and value <= ord("Z") else value
            )
        return

    var buffer_len = len(buffer)
    var aligned = math.align_down(buffer_len, SIMD_U8_WIDTH)
    var buf = Span(buffer)

    for s in range(0, aligned, SIMD_U8_WIDTH):
        var v = buf[s:].unsafe_ptr().load[width=SIMD_U8_WIDTH]()
        var ge_A = v >= CAPITAL_A
        var le_Z = v <= CAPITAL_Z
        var is_upper = ge_A.__and__(le_Z)
        var answer = is_upper.select(v + TO_LOWER_DIFF, v)
        buffer.unsafe_ptr().store(s, answer)

    for i in range(aligned, len(buffer)):
        var value = buffer[i]
        buffer[i] = (
            value + 32 if value >= ord("A") and value <= ord("Z") else value
        )
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))


fn find(haystack: Span[UInt8], needle: Span[UInt8]) -> Optional[Int]:
    """Look for the substring `needle` in the haystack.

    This returns the index of the start of the first occurrence of needle.
    """
<<<<<<< HEAD
=======
    # TODO: memchr/memmem probably
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))
    # https://github.com/BurntSushi/bstr/blob/master/src/ext_slice.rs#L3094
    # https://github.com/BurntSushi/memchr/blob/master/src/memmem/searcher.rs

    # Naive-ish search. Use our simd accel searcher to find the first char in the needle
    # check for extension, and move forward
    var start = 0
    while start < len(haystack):
<<<<<<< HEAD
        start = memchr(haystack, needle[0], start)
=======
        start = find_chr_next_occurrence_simd(haystack, needle[0], start)
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))
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

<<<<<<< HEAD
        var end = memchr(self.inner, self.split_on, self.current)
=======
        var end = find_chr_next_occurrence_simd(
            self.inner, self.split_on, self.current
        )
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))

        if end != -1:
            self.next_split = _StartEnd(self.current, end)
            self.current = end + 1
        else:
            self.next_split = _StartEnd(self.current, len(self.inner))
            self.current = len(self.inner) + 1
<<<<<<< HEAD

    fn peek(read self) -> Optional[Span[UInt8, origin]]:
        if self.next_split:
            var split = self.next_split.value()
            return self.inner[split.start : split.end]
        else:
            return None
=======
>>>>>>> b7f64d8 (Draft: feat: bstr like functionality in early stages (#5))

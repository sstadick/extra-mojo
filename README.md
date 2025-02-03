# ExtraMojo

Extra functionality to extend the Mojo std lib.

*Supports mojo 24.6.0*

## Install / Usage

Add `https://repo.prefix.dev/modular-community` to your project channels:

```
# mojoproject.toml or pixi.toml

[project]
channels = ["conda-forge", "https://conda.modular.com/max", "https://repo.prefix.dev/modular-community"]
description = "Add a short description here"
name = "my-mojo-project"
platforms = ["osx-arm64"]
version = "0.1.0"

[tasks]

[dependencies]
max = ">=24.5.0,<25"
```

then run:

```bash
magic add ExtraMojo
```

Or directly by following these instructions.

See docs for [numojo](https://github.com/Mojo-Numerics-and-Algorithms-group/NuMojo/tree/v0.3?tab=readme-ov-file#how-to-install) and just do that for this package until Mojo has true package / library support.

tl;dr;

In your project `mojo run -I "../ExtraMojo" my_example_file.mojo`.
Note the bit about how to add this project to your LSP so things resolve in VSCode.



## Tasks

```
magic run test
magic run format
magic run build
```

## Examples

Reading a file line by line.
```mojo
from ExtraMojo.io.buffered import BufferedReader, read_lines, for_each_line, BufferedWriter

fn test_buffered_writer(file: Path, expected_lines: List[String]) raises:
    var fh = BufferedWriter(open(str(file), "w"), buffer_capacity=128)
    for i in range(len(expected_lines)):
        fh.write_bytes(expected_lines[i].as_bytes())
        fh.write_bytes("\n".as_bytes())
    fh.close()

    test_read_until(str(file), expected_lines)

fn test_context_manager_simple(file: Path, expected_lines: List[String]) raises:
    var buffer = List[UInt8]()
    var counter = 0
    with BufferedReader(open(file, "r"), buffer_size=200) as reader:
        while reader.read_until(buffer) != 0:
            assert_equal(List(expected_lines[counter].as_bytes()), buffer)
            counter += 1
    assert_equal(counter, len(expected_lines))
    print("Successful read_until")


fn test_read_lines(file: Path, expected_lines: List[String]) raises:
    var lines = read_lines(str(file))
    assert_equal(len(lines), len(expected_lines))
    for i in range(0, len(lines)):
        assert_equal(lines[i], expected_lines[i].as_bytes())
    print("Successful read_lines")


fn test_for_each_line(file: Path, expected_lines: List[String]) raises:
    var counter = 0
    var found_bad = False

    @parameter
    fn inner(
        buffer: Span[UInt8], start: Int, end: Int
    ) capturing -> None:
        if (
            slice_tensor(buffer, start, end)
            != expected_lines[counter].as_bytes()
        ):
            found_bad = True
        counter += 1

    for_each_line[inner](str(file))
    assert_false(found_bad)
    print("Successful for_each_line")
```

Reading and Writing Simple Delimited Files

```python
from ExtraMojo.io.buffered import BufferedReader, BufferedWriter
from ExtraMojo.io.delimited import DelimReader, DelimWriter, FromDelimited, ToDelimited
from ExtraMojo.bstr.bstr import SplitIterator

from utils import StringSlice

@value
struct SerDerStruct(ToDelimited, FromDelimited):
    var index: Int
    var name: String

    fn write_to_delimited(read self, mut writer: DelimWriter) raises:
        writer.write_record(self.index, self.name)

    @staticmethod
    fn write_header(mut writer: DelimWriter) raises:
        writer.write_record("index", "name")

    @staticmethod
    fn from_delimited(mut data: SplitIterator) raises -> Self:
        var index = int(StringSlice(unsafe_from_utf8=data.__next__()))
        var name = String()  # String constructor expected nul terminated byte span
        name.write_bytes(data.__next__())
        return Self(index, name)


fn test_delim_reader_writer(file: Path) raises:
    var to_write = List[SerDerStruct]()
    for i in range(0, 1000):
        to_write.append(SerDerStruct(i, String("MyNameIs" + str(i))))
    var writer = DelimWriter[SerDerStruct](
        BufferedWriter(open(str(file), "w")), delim="\t", write_header=True
    )
    for item in to_write:
        item[].write_to_delimited(writer)
    writer.flush()
    writer.close()

    var reader = DelimReader[SerDerStruct](
        BufferedReader(open(str(file), "r")), delim=ord("\t"), has_header=True
    )
    var count = 0
    for item in reader^:
        assert_equal(to_write[count].index, item.index)
        assert_equal(to_write[count].name, item.name)
        count += 1
    assert_equal(count, len(to_write))
```

Simple Regex

**Note** you can also perform these matches on bytes.

```mojo
fn test_start_anchor() raises:
    var re = "^cat"
    assert_true(is_match(re, "cats of a feather"))
    assert_false(is_match(re, "bird cats of a cat"))


fn test_end_anchor() raises:
    var re = "what$"
    assert_true(is_match(re, "It is what"))
    assert_false(is_match(re, "what is in the box"))


fn test_dot() raises:
    var re = "w.t"
    assert_true(is_match(re, "Is that a witty remark?"))
    assert_false(is_match(re, "wt is that what thing there"))


fn test_star() raises:
    var re = "wha*"
    assert_true(is_match(re, "whaaaaaaat am I doing here"))
    assert_false(is_match(re, "wt am I doing here"))


fn test_literal() raises:
    var re = "ACTG"
    assert_true(is_match(re, "CTGGGACGCCCACTG"))
    assert_false(is_match(re, "CTGGGACGCCCACG"))


fn test_dot_star() raises:
    var re = "STAR.*"
    assert_true(is_match(re, "I'M A STAR!!!!!"))
    assert_false(is_match(re, "I'm not a STArsss"))


fn test_all() raises:
    assert_true(is_match("^cat.*$", "catsssssss"))
    assert_false(is_match("^cat.*$", "many catsssssss"))
```

Byte String functions:

```mojo
fn test_lowercase() raises:
    var example = List(
        "ABCdefgHIjklmnOPQRSTUVWXYZ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;ABCdefgHIjklmnOPQRSTUVWXYZ"
        .as_bytes()
    )
    var answer = "abcdefghijklmnopqrstuvwxyz;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;abcdefghijklmnopqrstuvwxyz"
    to_ascii_lowercase_simd(example)
    assert_equal(s(example), s(answer.as_bytes()))


fn test_find() raises:
    var haystack = "ABCDEFGhijklmnop".as_bytes()
    var expected = 4
    var answer = find(haystack, "EFG".as_bytes()).value()
    assert_equal(answer, expected)


fn test_spilt_iterator() raises:
    var input = "ABCD\tEFGH\tIJKL\nMNOP".as_bytes()
    var expected = List(
        "ABCD".as_bytes(), "EFGH".as_bytes(), "IJKL\nMNOP".as_bytes()
    )
    var output = List[Span[UInt8, StaticConstantOrigin]]()
    for value in SplitIterator(input, ord("\t")):
        output.append(value)
    for i in range(len(expected)):
        assert_equal(s(output[i]), s(expected[i]), "Not equal")

fn test_memchr() raises:
    var cases = List[(StringLiteral, Int)](
        (
            "enlivened,unleavened,Arnulfo's,Unilever's,unloved|Anouilh,analogue,analogy",
            49,
        ),
        (
            "enlivened,unleavened,Arnulfo's,Unilever's,unloved,Anouilh,analogue,analogy,enlivened,unleavened,Arnulfo's,Unilever's,unloved|Anouilh,analogue,analogy",
            124,
        ),
    )

    for kase in cases:
        var index = memchr(kase[][0].as_bytes(), ord("|"))
        assert_equal(index, kase[][1])

fn test_memchr_wide() raises:
    var cases = List[(StringLiteral, Int)](
        (
            "enlivened,unleavened,Arnulfo's,Unilever's,unloved|Anouilh,analogue,analogy",
            49,
        ),
        (
            "enlivened,unleavened,Arnulfo's,Unilever's,unloved,Anouilh,analogue,analogy,enlivened,unleavened,Arnulfo's,Unilever's,unloved|Anouilh,analogue,analogy",
            124,
        ),
    )

    for kase in cases:
        var index = memchr_wide(kase[][0].as_bytes(), ord("|"))
        assert_equal(index, kase[][1])
``


## Attribution

- Much of the first draft of the File and Tensor code was taken from [here](https://github.com/MoSafi2/MojoFastTrim/tree/restructed), which has now moved [here](https://github.com/MoSafi2/BlazeSeq).
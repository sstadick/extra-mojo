# xmojo
Extra functionality to extend the Mojo stdlib.

- supports mojo 24.6.0
---
## Getting Started with Mojo
See [Modular](https://docs.modular.com/) documentation to get started with the Modular stack.

## Install/Usage
### Build and Deploy Mojo Packages
See [Modular](https://docs.modular.com/mojo/manual/packages/) documention for modules and packages.

Also see [NuMojo](https://github.com/Mojo-Numerics-and-Algorithms-group/NuMojo/tree/v0.3?tab=readme-ov-file#how-to-install) documentation as further example with this package. Currently Mojo's package/library support is still under development.

tl;dr;

In your project `mojo run -I "../xmojo" my_example_file.🔥`.
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
from xmojo.fs.file import FileReader, read_lines, for_each_line
from xmojo.tensor import slice_tensor

fn test_context_manager_simple(file: Path, expected_lines: List[String]) raises:
    var buffer = List[UInt8]()
    var counter = 0
    with FileReader(open(file, "r"), buffer_size=200) as reader:
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

- Much of the first draft of the File and Tensor code was taken from [here](https://github.com/MoSafi2/BlazeSeq).
- xmojo is a derivative of the original [ExtraMojo](https://github.com/ExtraMojo/ExtraMojo) project. See link.

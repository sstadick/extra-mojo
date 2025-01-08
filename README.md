# xmojo v2

Extra functionality to extend the Mojo std lib.

*Supports mojo 24.6.0*

## Install / Usage

See docs for [numojo](https://github.com/Mojo-Numerics-and-Algorithms-group/NuMojo/tree/v0.3?tab=readme-ov-file#how-to-install) and just do that for this package until Mojo has true package / library support.

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

fn test_read_until(file: Path, expected_lines: List[String]) raises:
    var fh = open(file, "r")
    var reader = FileReader(fh^, buffer_size=1024)
    var buffer = List[UInt8]()
    var counter = 0
    while reader.read_until(buffer) != 0:
        assert_equal(expected_lines[counter].as_bytes(), buffer)
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
        buffer: Tensor[DType.uint8], start: Int, end: Int
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



## Attribution

- Much of the first draft of the File and Tensor code was taken from [here](https://github.com/MoSafi2/MojoFastTrim/tree/restructed), which has now moved [here](https://github.com/MoSafi2/BlazeSeq).

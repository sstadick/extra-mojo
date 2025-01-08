from pathlib import Path
from python import Python
from tensor import Tensor
from testing import *

from xmojo.fs.file import FileReader, read_lines, for_each_line
from xmojo.tensor import slice_tensor


fn create_file(path: String, lines: List[String]) raises:
    with open(path, "w") as fh:
        for i in range(len(lines)):
            fh.write(lines[i])
            fh.write(str("\n"))


fn strings_for_writing(size: Int) -> List[String]:
    var result = List[String]()
    for i in range(size):
        result.append("Line: " + str(i) + "X")
    return result


fn test_read_until(file: Path, expected_lines: List[String]) raises:
    var fh = open(file, "r")
    var reader = FileReader(fh^, buffer_size=1024)
    var buffer = List[UInt8]()
    var counter = 0
    while reader.read_until(buffer) != 0:
        assert_equal(List(expected_lines[counter].as_bytes()), buffer)
        counter += 1
    assert_equal(counter, len(expected_lines))
    print("Successful read_until")


fn test_read_lines(file: Path, expected_lines: List[String]) raises:
    var lines = read_lines(str(file))
    assert_equal(len(lines), len(expected_lines))
    for i in range(0, len(lines)):
        assert_equal(lines[i], List(expected_lines[i].as_bytes()))
    print("Successful read_lines")


fn test_for_each_line(file: Path, expected_lines: List[String]) raises:
    var counter = 0
    var found_bad = False

    @parameter
    fn inner(
        buffer: Tensor[DType.uint8], start: Int, end: Int
    ) capturing -> None:
        if slice_tensor(buffer, start, end) != List(
            expected_lines[counter].as_bytes()
        ):
            found_bad = True
        counter += 1

    for_each_line[inner](str(file))
    assert_false(found_bad)
    print("Successful for_each_line")


# https://github.com/modularml/mojo/issues/1753
# fn test_stringify() raises:
#     var example = List[Int8]()
#     example.append(ord("e"))
#     example.append(ord("x"))

#     var container = List[Int8]()
#     for i in range(len(example)):
#         container.append(example[i])
#     var stringifed = String(container)
#     assert_equal("ex", stringifed)
#    # Unhandled exception caught during execution: AssertionError: ex is not equal to e


fn main() raises:
    # TODO: use python to create a tempdir
    var tempfile = Python.import_module("tempfile")
    var tempdir = tempfile.TemporaryDirectory()
    var file = Path(str(tempdir.name)) / "lines.txt"
    var strings = strings_for_writing(10000)
    create_file(str(file), strings)

    # Tests
    test_read_until(str(file), strings)
    test_read_lines(str(file), strings)
    test_for_each_line(str(file), strings)

    print("SUCCESS")

    _ = tempdir.cleanup()

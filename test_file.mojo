from utils import StringSlice
from memory import Span
from pathlib import Path
from python import Python
from tensor import Tensor
from testing import *

from ExtraMojo.bstr.bstr import SplitIterator
from ExtraMojo.fs.delimited import DelimReader, FromBytes
from ExtraMojo.fs.file import (
    FileReader,
    read_lines,
    for_each_line,
    BufferedWriter,
)


fn s(bytes: Span[UInt8]) -> String:
    """Convert bytes to a String."""
    var buffer = String()
    buffer.write_bytes(bytes)
    return buffer


fn strings_for_writing(size: Int) -> List[String]:
    var result = List[String]()
    for i in range(size):
        result.append("Line: " + str(i) + " X" + ("-" * 64))  # make lines long
    return result


fn test_read_until(file: Path, expected_lines: List[String]) raises:
    var fh = open(file, "r")
    var reader = FileReader(fh^, buffer_size=200)
    var buffer = List[UInt8]()
    var counter = 0
    while reader.read_until(buffer) != 0:
        assert_equal(List(expected_lines[counter].as_bytes()), buffer)
        counter += 1
    assert_equal(counter, len(expected_lines))
    print("Successful read_until")


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
        assert_equal(lines[i], List(expected_lines[i].as_bytes()))
    print("Successful read_lines")


fn test_for_each_line(file: Path, expected_lines: List[String]) raises:
    var counter = 0
    var found_bad = False

    @parameter
    fn inner(buffer: Span[UInt8], start: Int, end: Int) capturing -> None:
        if s(buffer[start:end]) != expected_lines[counter]:
            found_bad = True
        counter += 1

    for_each_line[inner](str(file))
    assert_false(found_bad)
    print("Successful for_each_line")


fn test_delim_reader(file: Path, expected_lines: List[ExpectedLine]) raises:
    var reader = DelimReader[ExpectedLine](
        FileReader(open(str(file), "r")), delim=ord(" "), has_header=False
    )

    var count = 0
    for line in reader^:
        assert_equal(line.number, expected_lines[count].number)
        assert_equal(line.length, expected_lines[count].length)
        count += 1
    assert_equal(count, len(expected_lines))
    pass


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


fn test_buffered_writer(file: Path, expected_lines: List[String]) raises:
    var fh = BufferedWriter(open(str(file), "w"), buffer_capacity=128)
    for i in range(len(expected_lines)):
        fh.write_bytes(expected_lines[i].as_bytes())
        fh.write_bytes("\n".as_bytes())
    fh.close()

    test_read_until(str(file), expected_lines)


fn create_file(path: String, lines: List[String]) raises:
    with open(path, "w") as fh:
        for i in range(len(lines)):
            fh.write(lines[i])
            fh.write(str("\n"))


@value
struct ExpectedLine(FromBytes):
    var number: Int
    var length: Int

    @staticmethod
    fn from_bytes(mut data: SplitIterator) raises -> Self:
        var total_bytes = 0
        # Skip the first bit
        total_bytes += len(data.__next__())
        # Keep the line number
        var raw_number = data.__next__()
        total_bytes += len(raw_number)
        str_slice = StringSlice(unsafe_from_utf8=raw_number)
        line_number = int(
            str_slice
        )  # in next version Int(str_slice) should work
        # Save the total bytes
        total_bytes += len(data.__next__())
        total_bytes += 2

        return Self(line_number, total_bytes)


fn main() raises:
    # TODO: use python to create a tempdir
    var tempfile = Python.import_module("tempfile")
    var tempdir = tempfile.TemporaryDirectory()
    var file = Path(str(tempdir.name)) / "lines.txt"
    var strings = strings_for_writing(10000)
    var expected_for_delims = List[ExpectedLine]()
    for i in range(0, len(strings)):
        expected_for_delims.append(ExpectedLine(i, len(strings[i])))
    create_file(str(file), strings)

    # Tests
    test_read_until(str(file), strings)
    test_read_lines(str(file), strings)
    test_for_each_line(str(file), strings)
    test_buffered_writer(str(file), strings)
    test_delim_reader(str(file), expected_for_delims)

    print("SUCCESS")

    _ = tempdir.cleanup()

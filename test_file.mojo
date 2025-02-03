from utils import StringSlice
from memory import Span
from pathlib import Path
from python import Python
from tensor import Tensor
from testing import *

from ExtraMojo.bstr.bstr import SplitIterator
from ExtraMojo.io.delimited import (
    DelimReader,
    FromDelimited,
    ToDelimited,
    DelimWriter,
)
from ExtraMojo.io.buffered import (
    BufferedReader,
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
    var reader = BufferedReader(fh^, buffer_size=200)
    var buffer = List[UInt8]()
    var counter = 0
    while reader.read_until(buffer) != 0:
        assert_equal(List(expected_lines[counter].as_bytes()), buffer)
        counter += 1
    assert_equal(counter, len(expected_lines))
    print("Successful read_until")


fn test_read_bytes(file: Path) raises:
    var fh = open(file, "r")
    var reader = BufferedReader(fh^, buffer_size=50)
    var buffer = List[UInt8](capacity=125)
    for _ in range(0, 125):
        buffer.append(0)
    var found_file = List[UInt8]()

    # Read bytes from the buf reader, copy to found
    var bytes_read = 0
    while True:
        bytes_read = reader.read_bytes(buffer)
        if bytes_read == 0:
            break
        found_file.extend(buffer[0:bytes_read])
    # Last usage of reader, meaning it should call __del__ here.

    var expected = open(file, "r").read().as_bytes()
    assert_equal(len(expected), len(found_file))
    for i in range(0, len(expected)):
        assert_equal(
            expected[i], found_file[i], msg="Unequal at byte: " + str(i)
        )
    print("Successful read_bytes")


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
    print("Successful delim_writer")


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


fn main() raises:
    # TODO: use python to create a tempdir
    var tempfile = Python.import_module("tempfile")
    var tempdir = tempfile.TemporaryDirectory()
    var file = Path(str(tempdir.name)) / "lines.txt"
    var strings = strings_for_writing(10000)
    create_file(str(file), strings)

    # Tests
    test_read_until(str(file), strings)
    test_read_bytes(str(file))
    test_read_lines(str(file), strings)
    test_for_each_line(str(file), strings)
    var buf_writer_file = Path(str(tempdir.name)) / "buf_writer.txt"
    test_buffered_writer(str(buf_writer_file), strings)
    var delim_file = Path(str(tempdir.name)) / "delim.txt"
    test_delim_reader_writer(str(delim_file))

    print("SUCCESS")

    _ = tempdir.cleanup()

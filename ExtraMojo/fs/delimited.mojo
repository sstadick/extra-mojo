from collections import Optional
from memory import Span

from ExtraMojo.bstr.bstr import SplitIterator
from ExtraMojo.fs.file import FileReader


trait FromBytes(CollectionElement):
    """Create an inststance of [`Self`] from the iterator over [`Span[UInt8]`] bytes.
    """

    @staticmethod
    fn from_bytes(mut data: SplitIterator) raises -> Self:
        ...


struct DelimReader[RowType: FromBytes]:
    """Read delimited data that is delimited by a single bytes.

    The [`RowType`] must implement [`FromBytes`] which is passed an iterator over the split up line.
    """

    var delim: UInt8
    var reader: FileReader
    var next_elem: Optional[RowType]
    var buffer: List[UInt8]
    var len: Int
    var has_header: Bool

    fn __init__(
        out self, owned reader: FileReader, *, delim: UInt8, has_header: Bool
    ) raises:
        self.delim = delim
        self.reader = reader^
        self.next_elem = None
        self.buffer = List[UInt8]()
        self.len = 1
        self.has_header = has_header
        if self.has_header:
            self._skip_header()
        self._get_next()

    fn __moveinit__(out self, owned existing: Self):
        self.delim = existing.delim
        self.reader = existing.reader^
        self.next_elem = existing.next_elem^
        self.buffer = existing.buffer^
        self.len = existing.len
        self.has_header = existing.has_header

    fn __len__(read self) -> Int:
        return self.len

    fn __has_next__(read self) -> Bool:
        return self.__len__() > 0

    fn __next__(mut self) raises -> RowType:
        if not self.next_elem:
            raise "Attempting to call past end of iterator"
        var ret = self.next_elem.take()
        self._get_next()
        return ret

    fn __iter__(owned self) -> Self:
        return self^

    fn _skip_header(mut self) raises:
        var bytes_read = self.reader.read_until(self.buffer, ord("\n"))
        if bytes_read == 0:
            self.len = 0
            self.next_elem = None
            raise "No header found"

    fn _get_next(mut self) raises:
        var bytes_read = self.reader.read_until(self.buffer, ord("\n"))
        var tmp = String()
        tmp.write_bytes(self.buffer)
        if bytes_read == 0:
            self.len = 0
            self.next_elem = None
            return
        var iterator = SplitIterator(self.buffer, self.delim)
        self.next_elem = RowType.from_bytes(iterator)

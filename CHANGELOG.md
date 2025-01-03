# CHANGELOG

## v0.3.1

- Added MIT and Unlincense files.

## v0.3.0

- Fixed bug in find_next_chr that didn't use the passed in start on small inputs.
- Fixed bug in FileReader which wasn't deallocating its buffer on deletion.
- Improved the to_ascii_lowercase perf and added a corresponding to_ascii_uppercase.
- Added more tests for all the bstr methods to better cover the different code paths based on SIMD register sizes.

## v0.2.0

- Move FileReader from being backed by a tensor buffer to using a raw buffer with less copies.
- Added `bstr` package with basic support for split, find, and lowercasing of byte strings (more to come!)
- Added Span api for regex's
- Deleted a lot of the Tensor related helper code
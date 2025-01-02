# CHANGELOG

## v0.2.0

- Move FileReader from being backed by a tensor buffer to using a raw buffer with less copies.
- Added `bstr` package with basic support for split, find, and lowercasing of byte strings (more to come!)
- Added Span api for regex's
- Deleted a lot of the Tensor related helper code
"""
A very simple regex implemenation in Mojo inspired by Rob Pikes implementation.

https://www.cs.princeton.edu/courses/archive/spr09/cos333/beautiful.html
"""
from builtin.dtype import DType
from memory import Span

alias START_ANCHOR = ord("^")
alias END_ANCHOR = ord("$")
alias DOT = ord(".")
alias STAR = ord("*")
alias NULL = 0


fn is_match(regexp: String, text: String) -> Bool:
    """
    Search for regexp anywhere in text and return true if it matches.
    """
    var re = regexp.as_bytes()
    var txt = text.as_bytes()

    return is_match_bytes(re, txt)


fn is_match_bytes(regexp: Span[UInt8], text: Span[UInt8]) -> Bool:
    var txt = text
    var re = regexp
    if re[0] == START_ANCHOR:
        return is_match_here(re[1:], txt)

    while True:
        # Must look even if string is empty
        if is_match_here(re, txt):
            return True
        if txt[0] == NULL:
            break
        txt = txt[1:]

    return False


fn is_match_here(regexp: Span[UInt8], text: Span[UInt8]) -> Bool:
    """
    Search for regexp at beginning of text.
    """
    if regexp[0] == NULL:
        return True
    if regexp[1] == STAR:
        return is_match_star(regexp[0], regexp[2:], text)
    if regexp[0] == END_ANCHOR and regexp[1] == NULL:
        return text[0] == NULL
    if text[0] != NULL and (regexp[0] == DOT or regexp[0] == text[0]):
        return is_match_here(regexp[1:], text[1:])
    return False


fn is_match_star(c: UInt8, regexp: Span[UInt8], text: Span[UInt8]) -> Bool:
    """
    Search for c*regexp at beginning of text.
    """
    var txt = text
    while True:
        # a `*` matches zero or more instances
        if is_match_here(regexp, txt):
            return True

        if txt[0] == NULL or (txt[0] != c and c != DOT):
            break
        txt = txt[1:]
    return False

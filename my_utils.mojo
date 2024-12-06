"""
This module can't be called "utils" as this name is reserved by the Mojo standard library.
"""


from testing.testing import Testable


trait TestableCollectionElement(Testable, CollectionElement, Writable):
    pass


fn quick_sort[
    D: CollectionElement, lt: fn (D, D) capturing -> Bool
](inout vector: List[D]):
    _quick_sort[D, lt](vector, 0, len(vector) - 1)


fn _quick_sort[
    D: CollectionElement, lte: fn (D, D) capturing -> Bool
](inout vector: List[D], low: Int, high: Int):
    if low < high:
        var pi = _partition[D, lte](vector, low, high)
        _quick_sort[D, lte](vector, low, pi - 1)
        _quick_sort[D, lte](vector, pi + 1, high)


@always_inline
fn _partition[
    D: CollectionElement, lte: fn (D, D) capturing -> Bool
](inout vector: List[D], low: Int, high: Int) -> Int:
    var pivot = vector[high]
    var i = low - 1
    for j in range(low, high):
        if lte(vector[j], pivot):
            i += 1
            swap(vector, i, j)

    swap(vector, i + 1, high)
    return i + 1


@always_inline
fn swap[D: CollectionElement](inout vector: List[D], a: Int, b: Int):
    vector[a], vector[b] = vector[b], vector[a]


def print_list[T: TestableCollectionElement](list: List[T]) -> String:
    result = String("[")

    for i in range(len(list)):
        result += str(list[i])

        if i < len(list) - 1:
            result += ", "

    result += "]"

    return result


fn left_pad(binary_string: String, length: Int) -> String:
    """
    Left pads a binary string with zeroes for debugging purposes.

    Example input: "0b1", 5 -> "0b00001".
    """
    zeroes = String("")
    for _ in range(length - len(binary_string) + 2):
        zeroes += "0"
    return "0b" + zeroes + binary_string[2:]


fn my_bin(number: UInt64) -> String:
    return left_pad(bin(number), 64)

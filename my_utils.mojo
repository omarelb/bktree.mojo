from testing.testing import Testable


trait TestableCollectionElement(Testable, CollectionElement, Writable):
    pass


def print_list[T: TestableCollectionElement](list: List[T]) -> String:
    result = String("[")

    for i in range(len(list)):
        result += str(list[i])

        if i < len(list) - 1:
            result += ", "

    result += "]"

    return result

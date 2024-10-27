from collections import Optional
from testing import assert_equal, assert_raises
from my_utils import print_list
from bktree import BKTreeNode, BKTree, TestableCollectionElement


def test_tree_initialization():
    var root: Optional[BKTreeNode] = BKTreeNode("hello")
    var tree = BKTree(root)

    assert_optional_equal(tree.root, root)
    assert_equal(tree.root.value().text, "hello")
    assert_equal(tree.root.value().parent_distance, 0)
    assert_list_equal(tree.root.value().children, List[BKTreeNode]())


def test_add_existing_text_should_not_change_tree():
    var tree = BKTree()
    tree.insert_element("hello")
    tree.insert_element("hello")

    assert_optional_equal(tree.root, Optional(BKTreeNode("hello", 0)))
    assert_list_equal(tree.root.value().children, List[BKTreeNode]())


def test_add_children_to_root():
    tree = BKTree()
    tree.insert_element("book")

    assert_optional_equal(tree.root, Optional(BKTreeNode("book", 0)))
    assert_list_equal(tree.root.value().children, List[BKTreeNode]())

    tree.insert_element("books")
    assert_list_equal(
        tree.root.value().children,
        List[BKTreeNode](BKTreeNode("books", 1)),
    )


def test_add_child_with_new_child_distance():
    tree = BKTree()
    tree.insert_element("book")
    tree.insert_element("books")
    tree.insert_element("cake")

    root = tree.root.value()

    books_node = root.traverse("book->books")
    assert_optional_equal(books_node, Optional(BKTreeNode("books", 1)))

    cake_node = root.traverse("book->cake")
    assert_optional_equal(cake_node, Optional(BKTreeNode("cake", 4)))


def test_add_child_with_existing_child_distance():
    tree = BKTree()
    tree.insert_element("book")
    tree.insert_element("books")
    root = tree.root.value()
    books_node = root.traverse("book->books")
    assert_optional_equal(books_node, Optional(BKTreeNode("books", 1)))

    tree.insert_element("boo")
    boo_node = tree.root.value().traverse("book->books->boo")
    assert_equal(
        bool(boo_node),
        True,
        "boo node not found, should be an existing node with parent_distance 2",
    )
    assert_optional_equal(boo_node, Optional(BKTreeNode("boo", 2)))


def test_larger_example():
    tree = BKTree()
    tree.insert_element("book")
    tree.insert_element("books")

    assert_optional_equal(
        tree.root.value().traverse("book->books"),
        Optional(
            BKTreeNode(
                "books",
                1,
            )
        ),
    )

    tree.insert_element("boo")

    assert_optional_equal(
        tree.root.value().traverse("book->books->boo"),
        Optional(BKTreeNode("boo", 2)),
    )

    tree.insert_element("boon")

    assert_optional_equal(
        tree.root.value().traverse("book->books->boo->boon"),
        Optional(BKTreeNode("boon", 1)),
    )

    tree.insert_element("cook")

    assert_optional_equal(
        tree.root.value().traverse("book->books->boo->cook"),
        Optional(BKTreeNode("cook", 2)),
    )

    tree.insert_element("cake")
    assert_optional_equal(
        tree.root.value().traverse("book->cake"),
        Optional(BKTreeNode("cake", 4)),
    )

    tree.insert_element("cape")
    assert_optional_equal(
        tree.root.value().traverse("book->cake->cape"),
        Optional(BKTreeNode("cape", 1)),
    )

    tree.insert_element("cart")
    assert_optional_equal(
        tree.root.value().traverse("book->cake->cart"),
        Optional(BKTreeNode("cart", 2)),
    )


# def test_search_tree():
#     var elements: List[String] = List[String](
#         String("book"),
#         String("books"),
#         String("boo"),
#         String("boon"),
#         String("cook"),
#         String("cake"),
#         String("cape"),
#         String("cart"),
#     )

#     tree = BKTree(elements)

#     result = tree.search(String("books"), max_distance=0)

#     assert_optional_equal(result, Optional(String("books")))


def assert_optional_equal[
    T: TestableCollectionElement
](actual: Optional[T], expected: Optional[T]):
    assert_equal(
        bool(actual),
        bool(expected),
        "Optional values are not both None or not None",
    )

    if actual:
        assert_equal(actual.value(), expected.value())


def assert_list_equal[
    T: TestableCollectionElement
](actual: List[T], expected: List[T]):
    assert_equal(
        len(actual),
        len(expected),
        msg="length mismatch -- "
        + "actual: "
        + print_list(actual)
        + " expected: "
        + print_list(expected),
    )

    for i in range(len(actual)):
        assert_equal(
            actual[i],
            expected[i],
            msg="element "
            + str(i)
            + " mismatch\n"
            + "actual: "
            + print_list(actual)
            + " expected: "
            + print_list(expected),
        )

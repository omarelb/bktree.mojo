from python import Python
from memory import ArcPointer, Pointer, UnsafePointer
import os
from collections import Optional
from my_utils import TestableCollectionElement, quick_sort
from levenshtein import levenshtein_distance


@value
struct BKTreeNode(TestableCollectionElement):
    var text: String
    var parent_distance: Int
    var children: List[BKTreeNode]

    fn __init__(inout self: Self, text: String):
        self.text = text
        self.parent_distance = 0
        self.children = List[BKTreeNode]()

    fn __init__(inout self: BKTreeNode, text: String, parent_distance: Int):
        self.text = text
        self.parent_distance = parent_distance
        self.children = List[BKTreeNode]()

    fn __init__(
        inout self: BKTreeNode,
        text: String,
        parent_distance: Int,
        children: List[BKTreeNode],
    ):
        self.text = text
        self.parent_distance = parent_distance
        self.children = children

    fn __copyinit__(inout self: BKTreeNode, existing: BKTreeNode):
        self.text = existing.text
        self.parent_distance = existing.parent_distance
        self.children = existing.children

    fn __moveinit__(inout self: Self, owned existing: Self):
        self.text = existing.text^
        self.parent_distance = existing.parent_distance
        self.children = existing.children^

    fn add_child(inout self: BKTreeNode, child: BKTreeNode) -> None:
        self.children.append(child)

    fn traverse(self: BKTreeNode, path: String) raises -> Optional[BKTreeNode]:
        """
        Traverse the node's children using a path string, where each node text is separated by '->'.

        This makes testing easier, as we can easily traverse the tree using a string path.

        For example, if the tree has the following structure:

        root
        ├── a
        │   ├── b
        │   │   └── c
        │   └── d
        └── e
            └── f

        The path to get to node 'c' would be 'root->a->b->c', and the path to get to node 'f' would be 'root->e->f'.
        """
        # Handles the case where there's a single path without separator. This should
        # be the leaf node.
        if path == self.text:
            return self

        if path == "":
            return None

        path_parts = path.split("->")
        if len(path_parts) == 0:
            return None

        current_node = ArcPointer(self)

        if path_parts[0] != current_node[].text:
            return None

        path_parts = path_parts[1:]
        for child in self.children:
            result = child[].traverse("->".join(path_parts))
            if result:
                return result

        return None

    fn __eq__(self: Self, other: Self) -> Bool:
        return (
            self.text == other.text
            and self.parent_distance == other.parent_distance
            and len(self.children) == len(other.children)
        )

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "BKTreeNode(",
            "text='",
            self.text,
            "'",
            ", parent_distance=",
            str(self.parent_distance),
            ", num_children=",
            str(len(self.children)),
            ")",
        )

    fn __str__(self: BKTreeNode) -> String:
        return String.write(self)


@value
struct BKTree:
    """
    A [BK-tree](https://en.wikipedia.org/wiki/BK-tree) is useful for approximate string matching in a metric space.

    The tree is initialized once with a list of elements (in this case only strings are supported), after which
    it can be searched for elements that are within a certain distance of a query string using the Levenshtein distance.

    The BKTree is implemented as a tree structure, where each node has a text value and a distance to its parent node.
    """

    var root: Optional[BKTreeNode]

    fn __init__(inout self: Self, root: Optional[BKTreeNode] = None) -> None:
        self.root = root

    fn __init__(inout self: Self, elements: List[String]) raises -> None:
        self = BKTree()
        for i in range(len(elements)):
            self.insert_element(elements[i])

    fn insert_elements(
        inout self: Self, owned elements: List[String]
    ) raises -> None:
        for element in elements:
            self.insert_element(element[])

    fn insert_element(inout self: Self, text: String) raises -> None:
        """
        Insert a new element into the tree according to the BK-tree algorithm.

        Currently only strings and the Levenshtein distance are supported, but this could
        be made generic in the future.

        Args:
            text: The text of the node to insert into the tree.
        """
        if self.root is None:
            self.root = BKTreeNode(text=text, parent_distance=0)
            return

        current_node_reference = UnsafePointer.address_of(self.root.value())

        while True:
            distance_to_current_node = levenshtein_distance(
                current_node_reference[].text, text
            )

            if distance_to_current_node == 0:
                # We already have this word in the tree, do nothing.
                return

            var child_with_same_distance_reference: Optional[
                UnsafePointer[BKTreeNode, alignment=1]
            ] = None

            for child in current_node_reference[].children:
                if child[].parent_distance == distance_to_current_node:
                    child_with_same_distance_reference = (
                        UnsafePointer.address_of(child[])
                    )
                    break

            is_child_with_same_distance_found = (
                child_with_same_distance_reference is not None
            )
            if is_child_with_same_distance_found:
                current_node_reference = (
                    child_with_same_distance_reference.value()
                )
                continue

            new_node = BKTreeNode(
                text=text, parent_distance=distance_to_current_node
            )

            current_node_reference[].add_child(new_node)
            break

        return

    fn search(
        self: Self, query: String, max_distance: Int
    ) raises -> List[BKTreeSearchResult]:
        """
        Search the tree for elements that are within a certain (edit) distance of the query string.

        Args:
            query: The query string to search for.
            max_distance:
                The maximum distance from the query string that the search should return.
                A distance of 0 means that only exact matches are returned. The higher this value,
                the more results will be returned, but the slower the search will be.
        """
        if not self.root:
            return List[BKTreeSearchResult]()

        result = List[BKTreeSearchResult]()
        # NOTE: we use `UnsafePointer`s here to avoid copying the nodes, which is expensive. We're
        # using raw `UnsafePointer`s instead of Pointers here as the language is not fully fledged yet
        # and regular `Pointer`s are still quite limited.
        nodes_to_process = List[UnsafePointer[BKTreeNode]](
            UnsafePointer.address_of(self.root.value())
        )

        while len(nodes_to_process) > 0:
            current_node_ref = nodes_to_process.pop()
            current_node_distance_to_query = levenshtein_distance(
                current_node_ref[].text, query
            )

            # The current node is within the max distance, so we add it to the result.
            if current_node_distance_to_query <= max_distance:
                result.append(
                    BKTreeSearchResult(
                        text=current_node_ref[].text,
                        distance=current_node_distance_to_query,
                    )
                )

            for child in current_node_ref[].children:
                if (
                    abs(
                        child[].parent_distance - current_node_distance_to_query
                    )
                    <= max_distance
                ):
                    # Here we're also copying the child (I think), which is inefficient.
                    nodes_to_process.append(UnsafePointer.address_of(child[]))

        @parameter
        fn lt(a: BKTreeSearchResult, b: BKTreeSearchResult) capturing -> Bool:
            return a.distance < b.distance

        quick_sort[BKTreeSearchResult, lt](result)
        return result

    fn traverse(self: Self, path: String) raises -> Optional[BKTreeNode]:
        """
        Traverse the tree's nodes using a path string, where each node text is separated by '->'.

        This makes testing easier, as we can easily traverse the tree using a string path.

        For example, if the tree has the following structure:

        root
        ├── a
        │   ├── b
        │   │   └── c
        │   └── d
        └── e
            └── f

        The path to get to node 'c' would be 'root->a->b->c', and the path to get to node 'f' would be 'root->e->f'.
        """
        if not self.root:
            return None

        return self.root.value().traverse(path)


@value
struct BKTreeSearchResult(Writable, Stringable, EqualityComparable):
    """
    A search result from a BK-tree search, containing the text of the result
    and distance to the query string.
    """

    var text: String
    var distance: Int

    fn __init__(inout self: Self, text: String, distance: Int):
        self.text = text
        self.distance = distance

    fn __eq__(self: Self, other: Self) -> Bool:
        return self.text == other.text and self.distance == other.distance

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "BKTreeSearchResult(",
            "text='",
            self.text,
            "'",
            ", distance=",
            str(self.distance),
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)

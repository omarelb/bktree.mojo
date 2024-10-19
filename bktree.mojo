from python import Python
from collections import Optional
from my_utils import TestableCollectionElement, print_list


fn levenshtein_distance(a: String, b: String) raises -> Int:
    rapidfuzz = Python.import_module("rapidfuzz")

    return rapidfuzz.distance.Levenshtein.distance(a, b)


@always_inline
fn _partition[
    D: DType
](inout vector: List[SIMD[D, 1]], low: Int, high: Int) -> Int:
    var pivot = vector[high]
    var i = low - 1
    for j in range(low, high):
        if vector[j] <= pivot:
            i += 1
            vector[j], vector[i] = vector[i], vector[j]
    vector[i + 1], vector[high] = vector[high], vector[i + 1]
    return i + 1


fn _quick_sort[D: DType](inout vector: List[SIMD[D, 1]], low: Int, high: Int):
    if low < high:
        var pi = _partition(vector, low, high)
        _quick_sort(vector, low, pi - 1)
        _quick_sort(vector, pi + 1, high)


fn quick_sort[D: DType](inout vector: List[SIMD[D, 1]]):
    _quick_sort[D](vector, 0, len(vector) - 1)


@always_inline
fn swap[D: CollectionElement](inout vector: List[D], a: Int, b: Int):
    vector[a], vector[b] = vector[b], vector[a]


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


fn _quick_sort[
    D: CollectionElement, lte: fn (D, D) capturing -> Bool
](inout vector: List[D], low: Int, high: Int):
    if low < high:
        var pi = _partition[D, lte](vector, low, high)
        _quick_sort[D, lte](vector, low, pi - 1)
        _quick_sort[D, lte](vector, pi + 1, high)


fn quick_sort[
    D: CollectionElement, lt: fn (D, D) capturing -> Bool
](inout vector: List[D]):
    _quick_sort[D, lt](vector, 0, len(vector) - 1)


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

    fn __moveinit__(inout self: BKTreeNode, owned existing: BKTreeNode):
        self.text = existing.text^
        self.parent_distance = existing.parent_distance
        self.children = existing.children^

    fn add_child(inout self: BKTreeNode, child: BKTreeNode) -> None:
        self.children.append(child)

        @parameter
        fn lt(a: BKTreeNode, b: BKTreeNode) capturing -> Bool:
            return a.parent_distance < b.parent_distance

        quick_sort[BKTreeNode, lt](self.children)

    # fn __moveinit__(inout self, owned existing: Self):
    #     self.text = existing.text^
    #     self.parent_distance = existing.parent_distance
    #     self.children = existing.children^

    fn format_to(self: BKTreeNode, inout writer: Formatter) -> None:
        writer.write(
            "BKTreeNode("
            + "text='"
            + self.text
            + "'"
            + ", parent_distance="
            + str(self.parent_distance)
            + ", num_children="
            + str(len(self.children))
            + ")"
        )

    fn __eq__(self: Self, other: Self) -> Bool:
        return (
            self.text == other.text
            and self.parent_distance == other.parent_distance
            and len(self.children) == len(other.children)
        )

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn __str__(self: BKTreeNode) -> String:
        return String.format_sequence(self)

    fn traverse(self: BKTreeNode, path: String) raises -> Optional[BKTreeNode]:
        """Traverse the tree using a path string, where each node text is separated by '->'.""" 
        # Handles the case where there's a single path without separator. This should
        # be the leaf node.
        if path == self.text:
            return self

        if path == "":
            return None

        path_parts = path.split("->")
        if len(path_parts) == 0:
            return None

        current_node = Reference(self)

        if path_parts[0] != current_node[].text:
            return None

        path_parts = path_parts[1:]
        for child in self.children:
            result = child[].traverse("->".join(path_parts))
            if result:
                return result

        return None


@value
struct BKTree:
    var root: Optional[BKTreeNode]

    fn __init__(inout self: Self, root: Optional[BKTreeNode] = None) -> None:
        self.root = root

    fn traverse(self: Self, path: String) raises -> Optional[BKTreeNode]:
        if not self.root:
            return None

        return self.root.value().traverse(path)

    # TODO: make generic over distance metric and type of element.
    fn insert_element(inout self: Self, text: String) raises -> None:
        if self.root is None:
            self.root = BKTreeNode(text=text, parent_distance=0)
            return

        # TODO: turn UnsafePointer into a proper type like Reference.
        current_node_pointer = UnsafePointer[BKTreeNode].address_of(
            self.root.value()
        )

        while True:
            distance_to_current_node = levenshtein_distance(
                current_node_pointer[].text, text
            )

            if distance_to_current_node == 0:
                # We already have this word in the tree, do nothing.
                return

            var child_with_same_distance_pointer: Optional[
                UnsafePointer[BKTreeNode]
            ] = None
            for child in current_node_pointer[].children:
                if child[].parent_distance == distance_to_current_node:
                    child_with_same_distance_pointer = UnsafePointer[
                        BKTreeNode
                    ].address_of(child[])
                    break

            is_child_with_same_distance_found = (
                child_with_same_distance_pointer is not None
            )
            if is_child_with_same_distance_found:
                current_node_pointer = child_with_same_distance_pointer.value()
                continue

            current_node_pointer[].add_child(
                BKTreeNode(text=text, parent_distance=distance_to_current_node)
            )
            break

        return

fn main() raises:
    tree = BKTree()
    tree.insert_element("book")
    tree.insert_element("books")
    tree.insert_element("boo")
    boo_node = tree.root.value().traverse("book->books->boo")

    if boo_node:
        print(boo_node.value().text)
    else:
        print("boo node not found")

from python import Python
import os
from collections import Optional
from my_utils import TestableCollectionElement, print_list
import time
from memory import Pointer, Arc, UnsafePointer
from max.tensor import Tensor, TensorSpec, TensorShape
from collections.vector import InlinedFixedVector
from utils import Variant
import benchmark
from benchmark import Unit

from levenshtein import levenshtein_distance


fn levenshtein_distance_2(a: String, b: String) raises -> Int:
    t0 = time.perf_counter_ns()
    rapidfuzz = Python.import_module("rapidfuzz")
    t1 = time.perf_counter_ns()

    distance = rapidfuzz.distance.Levenshtein.distance(a, b)
    t2 = time.perf_counter_ns()

    # print("Time to import rapidfuzz:", (t1 - t0) / 1_000_000, "ms")
    # print("Time to calculate distance:", (t2 - t1) / 1_000_000, "ms")
    return distance


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

        @parameter
        fn lt(a: BKTreeNode, b: BKTreeNode) capturing -> Bool:
            return a.parent_distance < b.parent_distance

        quick_sort[BKTreeNode, lt](self.children)

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

    fn traverse(self: BKTreeNode, path: String) raises -> Optional[BKTreeNode]:
        """Traverse the tree using a path string, where each node text is separated by '->'.
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

        current_node = Arc(self)

        if path_parts[0] != current_node[].text:
            return None

        path_parts = path_parts[1:]
        for child in self.children:
            result = child[].traverse("->".join(path_parts))
            if result:
                return result

        return None


fn split_string_into_chars(string: String) -> List[String]:
    result = List[String](capacity=len(string))
    for i in range(len(string)):
        result.append(string[i : i + 1])
    return result


@value
struct BKTree:
    var root: Optional[BKTreeNode]

    fn __init__(inout self: Self, root: Optional[BKTreeNode] = None) -> None:
        self.root = root

    fn __init__(inout self: Self, elements: List[String]) raises -> None:
        self = BKTree()
        for i in range(len(elements)):
            if i % 1000 == 0:
                print("Inserting element", i)
            self.insert_element(elements[i])
        # for element in elements:
        #     self.insert_element(element[])

    fn traverse(self: Self, path: String) raises -> Optional[BKTreeNode]:
        if not self.root:
            return None

        return self.root.value().traverse(path)

    fn insert_elements(
        inout self: Self, owned elements: List[String]
    ) raises -> None:
        for element in elements:
            self.insert_element(element[])

    # TODO: make generic over distance metric and type of element.
    fn insert_element(inout self: Self, text: String) raises -> None:
        t0 = time.perf_counter_ns()
        if self.root is None:
            self.root = BKTreeNode(text=text, parent_distance=0)
            return

        t0 = time.perf_counter_ns()
        current_node_reference = Pointer.address_of(self.root.value())
        t1 = time.perf_counter_ns()
        # print(
        #     "Time to get root reference:",
        #     (t1 - t0) / 1,
        #     "ms",
        # )

        while True:
            t0 = time.perf_counter_ns()
            reference_split = split_string_into_chars(
                current_node_reference[].text
            )
            text_split = split_string_into_chars(text)
            t1 = time.perf_counter_ns()
            # print("Time to split strings:", (t1 - t0) / 1_000_000, "ms")

            tl = time.perf_counter_ns()

            distance_to_current_node = levenshtein_distance(
                reference_split, text_split
            ).cost
            # distance_to_current_node = levenshtein_distance_2(
            #     current_node_reference[].text, text
            # )
            tu = time.perf_counter_ns()
            # print("Time to calculate distance:", Float16(tu - tl) / 1_000, "μs")

            if distance_to_current_node == 0:
                # We already have this word in the tree, do nothing.
                return

            var child_with_same_distance_reference: Optional[
                Pointer[BKTreeNode, __origin_of(self.root._value)]
            ] = None

            for child in current_node_reference[].children:
                if child[].parent_distance == distance_to_current_node:
                    child_with_same_distance_reference = Pointer.address_of(
                        child[]
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

            t0 = time.perf_counter_ns()
            current_node_reference[].add_child(
                BKTreeNode(text=text, parent_distance=distance_to_current_node)
            )
            t1 = time.perf_counter_ns()
            # print(
            #     "Time to add child:",
            #     (t0 - t1) / 1_000_000,
            #     "ms",
            # )
            break

        t1 = time.perf_counter_ns()

        # print("Time to insert element:", (t1 - t0) / 1_000_000, "ms")

        return

    fn search(
        self: Self, query: String, max_distance: Int
    ) raises -> List[String]:
        if not self.root:
            return List[String]()

        result = List[String]()
        # Now we make a copy (I think), which is inefficient. Instead, we can use a reference.
        nodes_to_process = List[BKTreeNode](self.root.value())

        while len(nodes_to_process) > 0:
            current_node = nodes_to_process.pop()
            # current_node_distance_to_query = levenshtein_distance_2(
            #     current_node.text, query
            # )
            current_node_distance_to_query = levenshtein_distance(
                current_node.text, query
            ).cost

            # The current node is within the max distance, so we add it to the result.
            if current_node_distance_to_query <= max_distance:
                result.append(current_node.text)

            for child in current_node.children:
                if (
                    abs(
                        child[].parent_distance - current_node_distance_to_query
                    )
                    <= max_distance
                ):
                    # Here we're also copying the child (I think), which is inefficient.
                    nodes_to_process.append(child[])

        return result


fn main() raises:
    # max_distance = 1

    # t0 = time.perf_counter_ns()
    # # Open the file using a context manager
    # lines = List[String]()
    # with open("dutch_words.txt", "r") as file:
    #     # Read the entire content of the file
    #     t01 = time.perf_counter_ns()
    #     content = file.read()
    #     t02 = time.perf_counter_ns()
    #     lines = content.lower().split("\n")

    # print("opened words")

    # t1 = time.perf_counter_ns()
    # tree = BKTree(lines)
    # t2 = time.perf_counter_ns()

    # print("built tree")

    # query = "koperroo"

    # result = tree.search(query, max_distance)
    # print("searched")
    # t3 = time.perf_counter_ns()

    # print("Query: " + query)
    # if result:
    #     print("Found:", print_list(result))
    # else:
    #     print("Not found")

    # print("Time to open file:", (t01 - t0) / 1_000_000, "ms")
    # print("Time to read file content:", (t02 - t01) / 1_000_000, "ms")
    # print("Time to to split lines:", (t1 - t02) / 1_000_000, "ms")
    # print("Time to build tree:", (t2 - t1) / 1_000_000, "ms")
    # print("Time to search:", (t3 - t2) / 1_000_000, "ms")
    # print("Total time:", (t3 - t0) / 1_000_000, "ms")

    # original = "ik was er".split(" ")
    # transformed = "ik was".split(" ")

    # t0 = time.perf_counter_ns()
    # r = levenshtein_distance2(original, transformed)
    # t1 = time.perf_counter_ns()

    # print(r)

    # print("Time to calculate distance:", (t1 - t0) / 1_000_000, "ms")
    # var report = benchmark.run[lev_benchmark](max_iters=100000)

    # report.print(Unit.ms)

    str1 = "werkingsprincipe"
    str2 = "aanbranden"
    reference_split = split_string_into_chars(str1)
    text_split = split_string_into_chars(str2)
    t0 = time.perf_counter_ns()
    _ = levenshtein_distance(reference_split, text_split)
    t1 = time.perf_counter_ns()
    print("Time to calculate distance:", (t1 - t0) / 1_000_000, "ms")


fn lev_benchmark() raises:
    reference_split = List[String](
        String("w"),
        String("e"),
        String("r"),
        String("k"),
        String("i"),
        String("n"),
        String("g"),
        String("s"),
        String("p"),
        String("r"),
        String("i"),
        String("n"),
        String("c"),
        String("i"),
        String("p"),
        String("e"),
    )
    text_split = List[String](
        String("a"),
        String("a"),
        String("n"),
        String("b"),
        String("r"),
        String("a"),
        String("n"),
        String("d"),
        String("e"),
        String("n"),
    )
    # str1 = "werkingsprincipe"
    # str2 = "aanbranden"
    # reference_split = split_string_into_chars(str1)
    # text_split = split_string_into_chars(str2)
    _ = levenshtein_distance(reference_split, text_split)

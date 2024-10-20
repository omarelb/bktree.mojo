from utils import Variant
import time
from my_utils import TestableCollectionElement, print_list


@value
struct LevenshteinNode[T: TestableCollectionElement]:
    alias operation_type = Variant[
        LevenshteinSubstitution[T],
        LevenshteinInsertion[T],
        LevenshteinDeletion[T],
        NoneType,
    ]

    var cost: Int
    var operation: Self.operation_type

    fn __eq__(self: Self, other: Self) -> Bool:
        return self.cost == other.cost and levenshtein_operation_equal(
            self.operation, other.operation
        )

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "LevenshteinNode(",
            "cost=",
            str(self.cost),
            ", operation=",
            levenshtein_operation_print(self.operation),
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)


fn levenshtein_operation_print[
    T: TestableCollectionElement
](operation: LevenshteinNode[T].operation_type) -> String:
    if operation.isa[NoneType]():
        return "None"
    if operation.isa[LevenshteinSubstitution[T]]():
        return str(operation[LevenshteinSubstitution[T]])
    if operation.isa[LevenshteinInsertion[T]]():
        return str(operation[LevenshteinInsertion[T]])
    if operation.isa[LevenshteinDeletion[T]]():
        return str(operation[LevenshteinDeletion[T]])
    return "Unknown operation"


fn levenshtein_operation_equal[
    T: TestableCollectionElement
](
    a: LevenshteinNode[T].operation_type, b: LevenshteinNode[T].operation_type
) -> Bool:
    if a.isa[NoneType]() and b.isa[NoneType]():
        return True

    if (
        a.isa[LevenshteinSubstitution[T]]()
        and b.isa[LevenshteinSubstitution[T]]()
    ):
        var a_value = a[LevenshteinSubstitution[T]]
        var b_value = b[LevenshteinSubstitution[T]]
        return a_value == b_value

    if a.isa[LevenshteinInsertion[T]]() and b.isa[LevenshteinInsertion[T]]():
        var a_value = a[LevenshteinInsertion[T]]
        var b_value = b[LevenshteinInsertion[T]]
        return a_value == b_value

    if a.isa[LevenshteinDeletion[T]]() and b.isa[LevenshteinDeletion[T]]():
        var a_value = a[LevenshteinDeletion[T]]
        var b_value = b[LevenshteinDeletion[T]]
        return a_value == b_value

    return False


@value
struct LevenshteinSubstitution[T: TestableCollectionElement]:
    var original: T
    var replacement: T

    fn __eq__(self: Self, other: Self) -> Bool:
        return (
            self.original == other.original
            and self.replacement == other.replacement
        )

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "Substitution(",
            "original='",
            str(self.original),
            "'",
            ", replacement='",
            str(self.replacement),
            "'",
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)


@value
struct LevenshteinInsertion[T: TestableCollectionElement]:
    var inserted: T

    fn __eq__(self: Self, other: Self) -> Bool:
        return self.inserted == other.inserted

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "Insertion(",
            "inserted='",
            str(self.inserted),
            "'",
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)


@value
struct LevenshteinDeletion[T: TestableCollectionElement]:
    var deleted: T

    fn __eq__(self: Self, other: Self) -> Bool:
        return self.deleted == other.deleted

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "Deletion(",
            "deleted='",
            str(self.deleted),
            "'",
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)


struct Matrix[T: CollectionElement]:
    var data: List[List[T]]

    fn __init__(inout self: Self, num_rows: Int, num_cols: Int, value: T):
        self.data = List[List[T]](capacity=num_rows)
        for _ in range(num_rows):
            columns = List[T](capacity=num_cols)
            for _ in range(num_cols):
                columns.append(value)
            self.data.append(columns)

    fn __getitem__(
        ref [_]self: Self, *idx: Int
    ) -> ref [__origin_of(self.data)] T:
        return self.data[idx[0]][idx[1]]


@value
struct LevenshteinResult[T: TestableCollectionElement](Writable):
    var cost: Int
    var operations: List[LevenshteinNode[T]]

    fn write_to[W: Writer](self, inout writer: W):
        try:
            str_operations = print_list[LevenshteinNode[T]](self.operations)
        except:
            str_operations = "Some error occurred while printing operations"

        writer.write(
            "LevenshteinResult(",
            "cost=",
            str(self.cost),
            ", operations=",
            str_operations,
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)


fn levenshtein_distance[
    T: TestableCollectionElement
](original: List[T], transformed: List[T]) -> LevenshteinResult[T]:
    t0 = time.perf_counter_ns()

    m = len(original)
    n = len(transformed)

    node_matrix = Matrix[LevenshteinNode[T]](
        m + 1,
        n + 1,
        LevenshteinNode[T](cost=0, operation=NoneType()),
    )
    t00 = time.perf_counter_ns()

    # Initialize base cases
    for i in range(1, m + 1):
        node_matrix[i, 0] = LevenshteinNode[T](
            cost=i,
            operation=LevenshteinInsertion(inserted=original[i - 1]),
        )
    for j in range(1, n + 1):
        node_matrix[0, j] = LevenshteinNode[T](
            cost=j,
            operation=LevenshteinDeletion(deleted=transformed[j - 1]),
        )

    t01 = time.perf_counter_ns()

    # Fill the matrix
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            is_element_equal = original[i - 1] == transformed[j - 1]
            if is_element_equal:
                # No operation needed, copy the value from the diagonal,
                # as no cost is incurred.
                node_matrix[i, j].cost = node_matrix[i - 1, j - 1].cost
                node_matrix[i, j].operation = NoneType()
            else:
                deletion_cost = node_matrix[i - 1, j].cost
                insertion_cost = node_matrix[i, j - 1].cost
                substitution_cost = node_matrix[i - 1, j - 1].cost

                if (
                    deletion_cost < insertion_cost
                    and deletion_cost < substitution_cost
                ):
                    node = LevenshteinNode[T](
                        cost=1 + deletion_cost,
                        operation=LevenshteinDeletion(deleted=original[i - 1]),
                    )
                elif (
                    insertion_cost < deletion_cost
                    and insertion_cost < substitution_cost
                ):
                    node = LevenshteinNode[T](
                        cost=1 + insertion_cost,
                        operation=LevenshteinInsertion(
                            inserted=transformed[j - 1]
                        ),
                    )
                else:
                    node = LevenshteinNode[T](
                        cost=1 + substitution_cost,
                        operation=LevenshteinSubstitution(
                            original=original[i - 1],
                            replacement=transformed[j - 1],
                        ),
                    )

                node_matrix[i, j] = node

    t02 = time.perf_counter_ns()

    # Trace back
    operations = List[LevenshteinNode[T]]()
    i = m
    j = n

    while i > 0 and j > 0:
        current_node = node_matrix[i, j]
        operations.append(current_node)

        if current_node.operation.isa[NoneType]():
            i -= 1
            j -= 1
        elif current_node.operation.isa[LevenshteinDeletion[T]]():
            i -= 1
        elif current_node.operation.isa[LevenshteinInsertion[T]]():
            j -= 1
        else:
            i -= 1
            j -= 1

    t03 = time.perf_counter_ns()

    # Somehow if we do `operations.reverse()`, all the operations in the list
    # become `None`. Have to figure out why this happens.
    operations_reversed = List[LevenshteinNode[T]](capacity=len(operations))
    for i in range(len(operations) - 1, -1, -1):
        operations_reversed.append(operations[i])

    t04 = time.perf_counter_ns()

    result = LevenshteinResult(
        cost=node_matrix[m, n].cost, operations=operations_reversed
    )

    t1 = time.perf_counter_ns()

    total_time = t1 - t0

    print(
        "Time taken to initialize matrix:",
        (t00 - t0) / total_time * 100,
        "%",
    )

    print(
        "Time taken to initialize base cases:",
        (t01 - t00) / total_time * 100,
        "%",
    )

    print(
        "Time taken to fill the matrix:",
        (t02 - t01) / total_time * 100,
        "%",
    )

    print(
        "Time taken to trace back:",
        (t03 - t02) / total_time * 100,
        "%",
    )

    print(
        "Time taken to reverse operations:",
        (t04 - t03) / total_time * 100,
        "%",
    )

    print("Time taken to compute Levenshtein distance:", (t1 - t0) / 1_000_000, "ms")

    return result^
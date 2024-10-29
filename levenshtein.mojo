from utils import Variant
from memory import memset_zero, UnsafePointer
import time
from my_utils import TestableCollectionElement, print_list
from collections import InlinedFixedVector


alias Substitution = 0
alias Insertion = 1
alias Deletion = 2
alias Null = 3


# @value
struct LevenshteinNode[T: TestableCollectionElement]:
    # alias operation_type = Variant[
    #     LevenshteinSubstitution[T],
    #     LevenshteinInsertion[T],
    #     LevenshteinDeletion[T],
    #     NoneType,
    # ]

    var cost: Int
    # var operation: Self.operation_type
    var operation: Int

    fn __init__(inout self: Self, cost: Int, owned operation: Int):
        self.cost = cost
        self.operation = operation

    fn __copyinit__(inout self: Self, other: Self):
        self.cost = other.cost
        self.operation = other.operation

    fn __moveinit__(inout self: Self, owned other: Self):
        self.cost = other.cost
        self.operation = other.operation^

    fn __eq__(self: Self, other: Self) -> Bool:
        return self.cost == other.cost and self.operation == other.operation

    fn __ne__(self: Self, other: Self) -> Bool:
        return not (self == other)

    fn write_to[W: Writer](self, inout writer: W):
        writer.write(
            "LevenshteinNode(",
            "cost=",
            str(self.cost),
            ", operation=",
            operation_to_name(self.operation),
            ")",
        )

    fn __str__(self: Self) -> String:
        return String.write(self)


fn operation_to_name(operation: Int) -> String:
    if operation == Substitution:
        return "Substitution"
    if operation == Insertion:
        return "Insertion"
    if operation == Deletion:
        return "Deletion"
    if operation == Null:
        return "Null"
    return "Unknown operation"


# fn levenshtein_operation_print[
#     T: TestableCollectionElement
# ](operation: LevenshteinNode[T].operation_type) -> String:
#     if operation.isa[NoneType]():
#         return "None"
#     if operation.isa[LevenshteinSubstitution[T]]():
#         return str(operation[LevenshteinSubstitution[T]])
#     if operation.isa[LevenshteinInsertion[T]]():
#         return str(operation[LevenshteinInsertion[T]])
#     if operation.isa[LevenshteinDeletion[T]]():
#         return str(operation[LevenshteinDeletion[T]])
#     return "Unknown operation"


# fn levenshtein_operation_equal[
#     T: TestableCollectionElement
# ](
#     a: LevenshteinNode[T].operation_type, b: LevenshteinNode[T].operation_type
# ) -> Bool:
#     if a.isa[NoneType]() and b.isa[NoneType]():
#         return True

#     if (
#         a.isa[LevenshteinSubstitution[T]]()
#         and b.isa[LevenshteinSubstitution[T]]()
#     ):
#         var a_value = a[LevenshteinSubstitution[T]]
#         var b_value = b[LevenshteinSubstitution[T]]
#         return a_value == b_value

#     if a.isa[LevenshteinInsertion[T]]() and b.isa[LevenshteinInsertion[T]]():
#         var a_value = a[LevenshteinInsertion[T]]
#         var b_value = b[LevenshteinInsertion[T]]
#         return a_value == b_value

#     if a.isa[LevenshteinDeletion[T]]() and b.isa[LevenshteinDeletion[T]]():
#         var a_value = a[LevenshteinDeletion[T]]
#         var b_value = b[LevenshteinDeletion[T]]
#         return a_value == b_value

#     return False


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


struct Matrix[T: AnyTrivialRegType]:
    var _data: UnsafePointer[T]
    var num_rows: Int
    var num_cols: Int

    fn __init__(inout self, num_rows: Int, num_cols: Int):
        size = num_rows * num_cols
        debug_assert(size > 0, "must have more than 0 elements")
        self._data = UnsafePointer[T].alloc(size)
        memset_zero(self._data, size)
        self.num_rows = num_rows
        self.num_cols = num_cols

    fn __del__(owned self):
        self._data.free()

    fn __getitem__(self: Self, *idx: Int) -> T:
        debug_assert(
            0 <= idx[0] < self.num_rows, "row index must be within bounds"
        )
        debug_assert(
            0 <= idx[1] < self.num_cols, "col index must be within bounds"
        )
        index = self.row_col_to_index(idx[0], idx[1])
        return self._data[index]

    fn __setitem__(inout self: Self, *idx: Int, value: T):
        index = self.row_col_to_index(idx[0], idx[1])
        self._data[index] = value

    fn row_col_to_index(self, row: Int, col: Int) -> Int:
        return self.num_cols * row + col


@value
struct LevenshteinResult(Writable):
    # alias operation_type = Variant[
    #     LevenshteinSubstitution[T],
    #     LevenshteinInsertion[T],
    #     LevenshteinDeletion[T],
    #     NoneType,
    # ]

    var cost: Int
    var operations: List[Int]

    fn write_to[W: Writer](self, inout writer: W):
        try:
            str_operations = print_list(self.operations)
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


fn map_index_to_substring_index(
    index: Int, start_index: Int, end_index: Int
) -> Int:
    if index >= end_index:
        return end_index
    return index + start_index


fn levenshtein_distance(original: String, transformed: String) -> Int:
    start_index = 0
    original_end = len(original)
    transformed_end = len(transformed)

    # Skip common prefix and suffix. We don't use the slice syntax as it
    # allocates a new string which is slow.
    while (
        start_index < original_end
        and start_index < transformed_end
        and original.unsafe_ptr()[start_index]
        == transformed.unsafe_ptr()[start_index]
    ):
        start_index += 1

    while (
        start_index < original_end
        and start_index < transformed_end
        and original.unsafe_ptr()[original_end - 1]
        == transformed.unsafe_ptr()[transformed_end - 1]
    ):
        original_end -= 1
        transformed_end -= 1

    m = original_end - start_index
    n = transformed_end - start_index

    if start_index >= original_end or start_index >= transformed_end:
        return max(m, n) - min(m, n)

    cost_matrix = Matrix[Int](m + 1, n + 1)

    # Initialize base cases
    for i in range(1, m + 1):
        cost_matrix[i, 0] = i
    for j in range(1, n + 1):
        cost_matrix[0, j] = j

    # Fill the matrix
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            i_substr = map_index_to_substring_index(
                i, start_index, original_end
            )
            j_substr = map_index_to_substring_index(
                j, start_index, transformed_end
            )
            # If we don't use `unsafe_ptr()`, the strings are copied which seems
            # to be very slow.
            if (
                original.unsafe_ptr()[i_substr - 1]
                == transformed.unsafe_ptr()[j_substr - 1]
            ):
                this_substitution_cost = 0
            else:
                this_substitution_cost = 1

            deletion_cost = cost_matrix[i - 1, j] + 1
            insertion_cost = cost_matrix[i, j - 1] + 1
            substitution_cost = (
                cost_matrix[i - 1, j - 1] + this_substitution_cost
            )

            if (
                deletion_cost < insertion_cost
                and deletion_cost < substitution_cost
            ):
                cost = deletion_cost
            elif (
                insertion_cost < deletion_cost
                and insertion_cost < substitution_cost
            ):
                cost = insertion_cost
            else:
                cost = substitution_cost

            cost_matrix[i, j] = cost

    return cost_matrix[m, n]


fn levenshtein_distance[
    T: TestableCollectionElement
](original: List[T], transformed: List[T]) -> Int:
    m = len(original)
    n = len(transformed)

    cost_matrix = Matrix[Int](m + 1, n + 1)

    # Initialize base cases
    for i in range(1, m + 1):
        cost_matrix[i, 0] = i
    for j in range(1, n + 1):
        cost_matrix[0, j] = j

    # Fill the matrix
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            # is_element_equal = original[i - 1] == transformed[j - 1]
            if original[i - 1] == transformed[j - 1]:
                # No operation needed, copy the value from the diagonal,
                # as no cost is incurred.
                cost_matrix[i, j] = cost_matrix[i - 1, j - 1]
                this_substitution_cost = 0
            else:
                this_substitution_cost = 1

            deletion_cost = cost_matrix[i - 1, j] + 1
            insertion_cost = cost_matrix[i, j - 1] + 1
            substitution_cost = (
                cost_matrix[i - 1, j - 1] + this_substitution_cost
            )

            if (
                deletion_cost < insertion_cost
                and deletion_cost < substitution_cost
            ):
                cost = deletion_cost
            elif (
                insertion_cost < deletion_cost
                and insertion_cost < substitution_cost
            ):
                cost = insertion_cost
            else:
                cost = substitution_cost

            cost_matrix[i, j] = cost

    return cost_matrix[m, n]


fn levenshtein_distance2[
    T: TestableCollectionElement
](original: List[T], transformed: List[T]) -> LevenshteinResult:
    t0 = time.perf_counter_ns()

    m = len(original)
    n = len(transformed)

    cost_matrix = Matrix[Int](m + 1, n + 1)

    t00 = time.perf_counter_ns()

    # Initialize base cases
    for i in range(1, m + 1):
        cost_matrix[i, 0] = i
    for j in range(1, n + 1):
        cost_matrix[0, j] = j

    t01 = time.perf_counter_ns()

    # Fill the matrix
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            is_element_equal = original[i - 1] == transformed[j - 1]
            if is_element_equal:
                # No operation needed, copy the value from the diagonal,
                # as no cost is incurred.
                cost_matrix[i, j] = cost_matrix[i - 1, j - 1]
                # node_matrix[i, j].operation = NoneType()
            else:
                deletion_cost = cost_matrix[i - 1, j]
                insertion_cost = cost_matrix[i, j - 1]
                substitution_cost = cost_matrix[i - 1, j - 1]

                if (
                    deletion_cost < insertion_cost
                    and deletion_cost < substitution_cost
                ):
                    cost = 1 + deletion_cost
                # node = LevenshteinNode[T](
                #     cost=1 + deletion_cost,
                #     operation=LevenshteinDeletion(deleted=original[i - 1]),
                # )
                elif (
                    insertion_cost < deletion_cost
                    and insertion_cost < substitution_cost
                ):
                    cost = 1 + insertion_cost
                    # node = LevenshteinNode[T](
                    #     cost=1 + insertion_cost,
                    #     operation=LevenshteinInsertion(
                    #         inserted=transformed[j - 1]
                    #     ),
                    # )
                else:
                    cost = 1 + substitution_cost
                    # node = LevenshteinNode[T](
                    #     cost=1 + substitution_cost,
                    #     operation=LevenshteinSubstitution(
                    #         original=original[i - 1],
                    #         replacement=transformed[j - 1],
                    #     ),
                    # )

                cost_matrix[i, j] = cost

    t02 = time.perf_counter_ns()

    # alias operation_type = Variant[
    #     LevenshteinSubstitution[T],
    #     LevenshteinInsertion[T],
    #     LevenshteinDeletion[T],
    #     NoneType,
    # ]

    # Trace back
    operations_size = max(m, n)
    # operations = List[
    #     Variant[
    #         LevenshteinSubstitution[T],
    #         LevenshteinInsertion[T],
    #         LevenshteinDeletion[T],
    #         NoneType,
    #     ]
    # ](capacity=operations_size)
    operations = List[Int](capacity=operations_size)
    i = m
    j = n

    t021_sum = 0
    t022_sum = 0
    t023_sum = 0

    while i > 0 and j > 0:
        t020 = time.perf_counter_ns()
        current_node = cost_matrix[i, j]
        t021 = time.perf_counter_ns()
        # operations.append(current_node)
        t022 = time.perf_counter_ns()

        if i > 0 and j > 0 and original[i - 1] == transformed[j - 1]:
            i -= 1
            j -= 1
        elif i > 0 and (
            j == 0 or cost_matrix[i, j] == cost_matrix[i - 1, j] + 1
        ):
            # operations.append(LevenshteinDeletion(deleted=original[i - 1]))
            operations.append(Deletion)
            i -= 1
        elif j > 0 and (
            i == 0 or cost_matrix[i, j] == cost_matrix[i, j - 1] + 1
        ):
            # operations.append(LevenshteinInsertion(inserted=transformed[j - 1]))
            operations.append(Insertion)
            j -= 1
        else:
            # operations.append(
            #     LevenshteinSubstitution(
            #         original=original[i - 1],
            #         replacement=transformed[j - 1],
            #     )
            # )
            operations.append(Substitution)
            i -= 1
            j -= 1

        # if current_node.operation.isa[NoneType]():
        #     i -= 1
        #     j -= 1
        # elif current_node.operation.isa[LevenshteinDeletion[T]]():
        #     i -= 1
        # elif current_node.operation.isa[LevenshteinInsertion[T]]():
        #     j -= 1
        # else:
        #     i -= 1
        #     j -= 1

        t023 = time.perf_counter_ns()

        t021_sum += t021 - t020
        t022_sum += t022 - t021
        t023_sum += t023 - t022

    t03 = time.perf_counter_ns()

    # Somehow if we do `operations.reverse()`, all the operations in the list
    # become `None`. Have to figure out why this happens.
    # operations_reversed = List[
    #     Variant[
    #         LevenshteinSubstitution[T],
    #         LevenshteinInsertion[T],
    #         LevenshteinDeletion[T],
    #         NoneType,
    #     ]
    # ](capacity=len(operations))
    # for i in range(len(operations) - 1, -1, -1):
    #     operations_reversed.append(operations[i])
    operations.reverse()

    t04 = time.perf_counter_ns()

    result = LevenshteinResult(cost=cost_matrix[m, n], operations=operations)

    t1 = time.perf_counter_ns()

    total_time = t1 - t0

    # print(
    #     "Time taken to initialize matrix:",
    #     (t00 - t0) / Float32(total_time) * 100,
    #     "%",
    #     " = ",
    #     t00 - t0,
    #     "ns",
    # )

    # print(
    #     "Time taken to initialize base cases:",
    #     t01 - t00 / total_time * 100,
    #     "%",
    # )

    # print(
    #     "Time taken to fill the matrix:",
    #     (t02 - t01) / total_time * 100,
    #     "%",
    # )

    # print(
    #     "Time taken for 'current_node = node_matrix[i, j]':",
    #     t021_sum / total_time * 100,
    #     "%",
    #     " = ",
    #     (t021_sum) / 1_000_000,
    #     "ns",
    # )

    # print(
    #     "Time taken to append current_node to operations:",
    #     t022_sum / total_time * 100,
    #     "%",
    #     " = ",
    #     (t022_sum) / 1_000_000,
    #     "ns",
    # )

    # print(
    #     "Time taken to update i and j:",
    #     t023_sum / total_time * 100,
    #     "%",
    #     " = ",
    #     (t023_sum) / 1_000_000,
    #     "ns",
    # )

    # print(
    #     "Time taken to trace back:",
    #     (t03 - t02) / total_time * 100,
    #     "%",
    #     " = ",
    #     (t03 - t02) / 1_000_000,
    #     "ns",
    # )

    # print(
    #     "Time taken to reverse operations:",
    #     (t04 - t03) / total_time * 100,
    #     "%",
    # )

    # print(
    #     "Time taken to compute Levenshtein distance:",
    #     (t1 - t0) / 1_000_000,
    #     "ns",
    # )

    return result^

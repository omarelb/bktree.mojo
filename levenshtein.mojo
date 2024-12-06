from memory import memset_zero, UnsafePointer
from python import Python


fn levenshtein_distance(
    original: String,
    transformed: String,
    score_cutoff: Int = Int.MAX,
) -> Int:
    """
    Return the Levenshtein distance between two strings, which is the minimum
    number of single-character edits (insertions, deletions, or substitutions)
    required to change one string into the other.

    The `score_cutoff` parameter can be used to stop the calculation early if the
    distance exceeds the given value. This can be used to speed up the calculation
    if the distance is not needed exactly. If the distance is greater than the
    `score_cutoff`, `score_cutoff + 1` is returned.
    """
    return levenshtein_distance_wagner_fischer_cached(
        original, transformed, score_cutoff
    )


fn levenshtein_distance_wagner_fischer_cached(
    original: String,
    transformed: String,
    score_cutoff: Int = Int.MAX,
) -> Int:
    """
    Calculate the Levenshtein distance between two strings using the Wagner-
    Fischer algorithm (dynamic programming). Instead of storing the whole matrix,
    we store only the previous column of the matrix, which saves space. This
    has O(original) space complexity compared to the O(original * transformed)
    space complexity of the vanilla Wagner-Fischer algorithm.

    Note that we go column by column in the matrix, where the column corresponds to
    the `original` string and a row corresponds to the `transformed` string.
    """
    cache_size = len(original) + 1
    cache = List[Int](capacity=cache_size)
    debug_assert(cache_size > 0, "cache size must be greater than 0")

    # Initialize the cache with deletion costs. We go column by column in the
    # matrix, so this is the first column.
    for i in range(cache_size):
        cache.append(i)

    for transformed_character in transformed.as_string_slice():
        # We need the previous diagonal element to calculate the substitution
        # cost.
        temp = cache[0]
        j = 0

        # Initialize the first element of the column with the insertion cost.
        cache[0] += 1

        for original_character in original.as_string_slice():
            if original_character != transformed_character:
                temp = min(
                    min(
                        # insertion
                        cache[j] + 1,
                        # deletion
                        cache[j + 1] + 1,
                    ),
                    # substitution
                    temp + 1,
                )

            j += 1
            swap(temp, cache[j])

    distance = cache[cache_size - 1]
    if distance > score_cutoff:
        return score_cutoff + 1
    return distance


fn levenshtein_distance_wagner_fischer(
    original: String,
    transformed: String,
    score_cutoff: Int = Int.MAX,
) -> Int:
    """
    Calculate the Levenshtein distance between two strings using the Wagner-
    Fischer algorithm (dynamic programming). This implementation uses a matrix
    to store the costs of the operations. The space complexity is O(original *
    transformed).
    """
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


fn levenshtein_distance_rapidfuzz(a: String, b: String) raises -> Int:
    """
    Return the Levenshtein distance between two strings using the Python
    rapidfuzz library.
    """
    rapidfuzz = Python.import_module("rapidfuzz")
    return rapidfuzz.distance.Levenshtein.distance(a, b)


fn map_index_to_substring_index(
    index: Int, start_index: Int, end_index: Int
) -> Int:
    """
    Map an index in the range [0, end_index - start_index) to an index in the
    range [start_index, end_index).

    This function is used to avoid a String allocation when accessing a string that should
    have a common prefix or suffix removed. It can probably be done better but I don't know
    Mojo well enough to do it.
    """
    if index >= end_index:
        return end_index
    return index + start_index


struct Matrix[T: AnyTrivialRegType]:
    """
    A simple matrix implementation that stores the data in a single array, but allows
    2D indexing.

    Accessing elements is done with `matrix[row, col]`.
    """

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

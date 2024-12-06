from memory import memset_zero, UnsafePointer
from levenshtein import (
    levenshtein_distance,
    levenshtein_distance_wagner_fischer_cached,
)


struct PatternMatchVector:
    # TODO: for now we only handle (extended) ASCII characters
    var extendedAscii: SafeBuffer[UInt64]

    fn __init__(inout self):
        self.extendedAscii = SafeBuffer[UInt64](256)

    fn __init__(inout self, original: String):
        self = Self()

        self.insert(original)

    fn insert(inout self, original: String):
        var mask: UInt64 = 1
        for character in original.as_string_slice():
            self.extendedAscii[ord(character)] |= mask
            mask <<= 1

    fn __getitem__(self, character: String) -> UInt64:
        return self.extendedAscii[ord(character)]


fn levenshtein_distance_optimized(
    original: String,
    transformed: String,
    score_cutoff: Int = Int.MAX,
) -> Int:
    """
    Return the Levenshtein distance between two strings (see `levenshtein_distance` docstring
    for more information). This implementation adds extra optimizations, inspired by the
    `RapidFuzz` implementation.

    WARNING: while this implemenetation should be faster, it is currently slower in most cases.
    This is likely due to extra string allocations which currently seem to be very slow in Mojo.
    """
    # Swapping the strings so the first string is shorter.
    if len(original) > len(transformed):
        return levenshtein_distance(transformed, original, score_cutoff)

    # The distance between the two strings can't be more than either of their lengths.
    score_cutoff_upper_bound = min(
        score_cutoff, max(len(original), len(transformed))
    )

    # When no differences are allowed, a direct comparision is sufficient.
    if score_cutoff_upper_bound == 0:
        return original != transformed

    # If the difference in length is greater than the score cutoff, we already know the distance
    # will at least be greater than the score cutoff, which means we can return early.
    if len(transformed) - len(original) > score_cutoff_upper_bound:
        return score_cutoff_upper_bound + 1

    # Common affix doesn't affect the Levenshtein distance, so we remove it.
    # TODO: prevent the copy here, which is slow.
    original_without_common_affix, transformed_without_common_affix = (
        remove_common_affix(original, transformed)
    )
    # If either is empty, the distance is the length of the other.
    if (
        len(original_without_common_affix) == 0
        or len(transformed_without_common_affix) == 0
    ):
        return len(original_without_common_affix) + len(
            transformed_without_common_affix
        )

    # When the short string has less then 65 elements Hyyrös' algorithm can be used.
    # This algorithm works with bitmasks, we can have 64 elements in a single UInt64.
    if len(original_without_common_affix) < 65:
        return levenshtein_hyrroe2003(
            PatternMatchVector(original_without_common_affix),
            original_without_common_affix,
            transformed_without_common_affix,
            score_cutoff_upper_bound,
        )

    return levenshtein_distance_wagner_fischer_cached(
        original, transformed, score_cutoff
    )


fn levenshtein_hyrroe2003(
    pattern_match_vector: PatternMatchVector,
    original: String,
    transformed: String,
    score_cutoff: Int,
) -> Int:
    """
    Return Levenshtein distance using the algorithm by Hyyrö (2002) [1]. This algorithm
    is optimized for strings shorter than 64 characters and uses bitmasks to represent the pattern match
    vector. This implementation is based on the RapidFuzz implementation.

    Usage:
    ```
    s = String("kitten")
    print(
        levenshtein_hyrroe2003(PatternMatchVector(s), s, String("sitting"), 0)
    )
    ```

    [1] A Bit-Vector Algorithm for Computing Levenshtein and Damerau Edit Distances - Heikki Hyyrö (2002)
    """
    # Set VP to 1^m.
    var VP: UInt64 = ~0
    var VN: UInt64 = 0
    var m = len(original)
    dist = m

    var mask: UInt64 = 1 << (len(original) - 1)

    for j in range(len(transformed)):
        PM_j = pattern_match_vector[transformed[j]]
        X = PM_j
        D0 = (((X & VP) + VP) ^ VP) | X | VN

        # Computing HP and HN
        var HP = VN | ~(D0 | VP)
        var HN = D0 & VP

        # Step 3: Computing the value D[m,j]
        dist += bool(HP & mask)
        dist -= bool(HN & mask)

        # Computing VP and VN
        HP = (HP << 1) | 1
        HN = HN << 1

        VP = HN | ~(D0 | HP)
        VN = HP & D0

    return dist


fn remove_common_affix(
    original: String, transformed: String
) -> Tuple[String, String]:
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

    # TODO: check if we can avoid the copy here, which is slow.
    return (
        original[start_index:original_end],
        transformed[start_index:transformed_end],
    )


struct SafeBuffer[T: AnyTrivialRegType]:
    var _data: UnsafePointer[T]
    var _size: Int

    fn __init__(inout self, size: Int):
        self._data = UnsafePointer[T].alloc(size)
        memset_zero(self._data, size)
        self._size = size

    fn __del__(owned self):
        self._data.free()

    fn __getitem__(self, index: Int) -> T:
        debug_assert(0 <= index < self._size, "index out of bounds")
        return self._data[index]

    fn __setitem__(inout self, index: Int, value: T):
        debug_assert(0 <= index < self._size, "index out of bounds")
        self._data[index] = value

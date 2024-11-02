from levenshtein import (
    levenshtein_distance,
    levenshtein_distance_wagner_fischer_cached,
)
from testing import assert_equal


def test_levenshtein_distance_empty_strings():
    assert_equal(levenshtein_distance("", ""), 0)


def test_levenshtein_distance_empty_and_non_empty():
    assert_equal(levenshtein_distance("", "hello"), 5)
    assert_equal(levenshtein_distance("hello", ""), 5)


def test_levenshtein_distance_identical_strings():
    assert_equal(levenshtein_distance("hello", "hello"), 0)
    assert_equal(levenshtein_distance("test", "test"), 0)


def test_levenshtein_distance_single_character_operations():
    # Single insertion
    assert_equal(levenshtein_distance("cat", "cats"), 1)
    # Single deletion
    assert_equal(levenshtein_distance("cats", "cat"), 1)
    # Single substitution
    assert_equal(levenshtein_distance("cat", "cut"), 1)


def test_levenshtein_distance_multiple_operations():
    assert_equal(levenshtein_distance("kitten", "sitting"), 3)
    assert_equal(levenshtein_distance("sunday", "saturday"), 3)
    assert_equal(levenshtein_distance("hello", "world"), 4)


def test_levenshtein_distance_case_sensitivity():
    assert_equal(levenshtein_distance("Hello", "hello"), 1)
    assert_equal(levenshtein_distance("WORLD", "world"), 5)


# def test_levenshtein_distance_with_score_cutoff():
#     assert_equal(levenshtein_distance("kitten", "sitting", score_cutoff=2), 3)
#     assert_equal(levenshtein_distance("kitten", "sitting", score_cutoff=1), 2)
#     assert_equal(levenshtein_distance("hello", "world", score_cutoff=3), 4)
#     assert_equal(levenshtein_distance("hello", "world", score_cutoff=2), 3)


def test_levenshtein_distance_special_characters():
    assert_equal(levenshtein_distance("hello!", "hello?"), 1)
    assert_equal(levenshtein_distance("@#$", "@#$"), 0)
    assert_equal(levenshtein_distance("user@example.com", "user@sample.com"), 2)


def test_levenshtein_distance_different_length_strings():
    assert_equal(levenshtein_distance("short", "very long string"), 14)
    assert_equal(levenshtein_distance("a", "abc"), 2)
    assert_equal(levenshtein_distance("abc", "a"), 2)


def test_levenshtein_wagner_fischer_cached():
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("short", "very long string"),
        14,
    )
    assert_equal(levenshtein_distance_wagner_fischer_cached("a", "abc"), 2)
    assert_equal(levenshtein_distance_wagner_fischer_cached("abc", "a"), 2)
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("hello", "hello"), 0
    )
    assert_equal(levenshtein_distance_wagner_fischer_cached("test", "test"), 0)
    assert_equal(levenshtein_distance_wagner_fischer_cached("cat", "cats"), 1)
    assert_equal(levenshtein_distance_wagner_fischer_cached("cats", "cat"), 1)
    assert_equal(levenshtein_distance_wagner_fischer_cached("cat", "cut"), 1)
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("kitten", "sitting"), 3
    )
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("sunday", "saturday"), 3
    )
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("hello", "world"), 4
    )
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("Hello", "hello"), 1
    )
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("WORLD", "world"), 5
    )
    assert_equal(
        levenshtein_distance_wagner_fischer_cached("hello!", "hello?"), 1
    )
    assert_equal(levenshtein_distance_wagner_fischer_cached("@#$", "@#$"), 0)

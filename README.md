# Mojo BK-Tree

This repository contains a quick experiment with BK-trees in Mojo. Please note that this is not production-ready code.
As Mojo is still in heavy development at the time of writing (Oct 2024), a nightly version is used. This may cause issues with the code in the future.

## Overview

A `BK-tree` is a data structure that is useful for approximate string matching in a metric space. This project is a simple implementation in Mojo to explore the concept and whether a more efficient implementation is possible.

The most important elements of the project are:

- **bktree.mojo**: Contains the `BKTree` struct, which has methods for constructing a `BKTree` and querying it. Currently only the Levenshtein distance is supported.
- **levenshtein.mojo**: Contains the `levenshtein_distance` function, which calculates the Levenshtein distance between two strings.

## Usage

To use the BK-tree, you can create a new `BKTree` and add strings to it. You can then query the tree to find strings that are within a certain distance of a query string.

```mojo
from bktree import BKTree

with open("my_strings.txt", "r") as file:
    content = file.read()
    words = content.lower().split("\n")

tree = BKTree(words)

nodes = tree.search("hello", max_distance=1)

if len(nodes) > 0:
    print("Found matches:")
    for node in nodes:
        print(node)
else:
    print("No matches found.")
```

## Disclaimer

This code is experimental and not intended for production use. It may contain bugs and is not optimized for performance.

## License

This project is licensed under the MIT License.

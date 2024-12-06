# Mojo BK-Tree

This repository contains a quick experiment with BK-trees in Mojo. Please note that this is not production-ready code.
As Mojo is still in heavy development at the time of writing (Oct 2024), a nightly version is used. This may cause issues with the code in the future.

## Overview

A `BK-tree` is a data structure that is useful for approximate string matching in a metric space. This project is a simple implementation in Mojo to explore the concept and whether a more efficient implementation is possible.

The most important elements of the project are:

- **bktree.mojo**: Contains the `BKTree` struct, which has methods for constructing a `BKTree` and querying it. Currently only the Levenshtein distance is supported.
- **levenshtein.mojo**: Contains the `levenshtein_distance` function, which calculates the Levenshtein distance between two strings.

## Disclaimer

This code is experimental and not intended for production use. It may contain bugs and is not optimized for performance.

## License

This project is licensed under the MIT License.

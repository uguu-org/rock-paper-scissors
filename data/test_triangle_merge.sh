#!/bin/bash

if [[ $# -ne 1 ]]; then
   echo "$0 {triangle_merge.exe}"
   exit 1
fi
TOOL=$1
TEST_DIR=$(mktemp -d)

set -euo pipefail

function die
{
   echo "$1"
   rm -rf "$TEST_DIR"
   exit 1
}

# Generate test input.
INPUT1="$TEST_DIR/a.png"
cat <<EOT | pnmtopng > "$INPUT1"
P2
10 9
255
1  2  3  4    11 12 13 14   21 22
5  6  7  0    15 16 17 0    23 24
8  9  0  0    18 19 0  0    25 26
10 0  0  0    20 0  0  0    27 0

28 29 30 31   38 39 40 41   48 49
32 33 34 0    42 43 44 0    50 51
35 36 0  0    45 46 0  0    52 53
37 0  0  0    47 0  0  0    54 0

55 56 57 58   59 60 61 62   63 64
EOT
INPUT2="$TEST_DIR/b.png"
cat <<EOT | pnmtopng > "$INPUT2"
P2
10 9
255
0  0  0  0    0  0  0  0    0  0
0  0  0  88   0  0  0  76   0  0
0  0  94 89   0  0  82 77   0  0
0  98 95 90   0  86 83 78   0  74

0  0  0  0    0  0  0  0    0  0
0  0  0  91   0  0  0  79   0  0
0  0  96 92   0  0  84 80   0  0
0  99 97 93   0  87 85 81   0  75

0  0  0  0    0  0  0  0    0  0
EOT

EXPECTED="$TEST_DIR/expected.pgm"
cat <<EOT > "$EXPECTED"
P2
10 9
255
1  2  3  4    11 12 13 14   21 22
5  6  7  88   15 16 17 76   23 24
8  9  94 89   18 19 82 77   25 26
10 98 95 90   20 86 83 78   27 74

28 29 30 31   38 39 40 41   48 49
32 33 34 91   42 43 44 79   50 51
35 36 96 92   45 46 84 80   52 53
37 99 97 93   47 87 85 81   54 75

55 56 57 58   59 60 61 62   63 64
EOT

# Run tool.
ACTUAL="$TEST_DIR/actual.png"
"./$TOOL" 4 "$INPUT1" "$INPUT2" "$ACTUAL" || die "$TOOL failed: $?"

# Check output.
EXPECTED_NORMALIZED="$TEST_DIR/a.txt"
ppmtopgm -plain "$EXPECTED" > "$EXPECTED_NORMALIZED"
ACTUAL_NORMALIZED="$TEST_DIR/b.txt"
pngtopnm "$TEST_DIR/actual.png" | ppmtopgm -plain > "$ACTUAL_NORMALIZED"

if ! ( diff "$EXPECTED_NORMALIZED" "$ACTUAL_NORMALIZED" ); then
   die "Output mismatched"
fi

# Cleanup.
rm -rf "$TEST_DIR"
exit 0

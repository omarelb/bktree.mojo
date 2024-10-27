from benchmark.quick_bench import QuickBench
from benchmark.bencher import Bench, BenchId, Bencher
from levenshtein import levenshtein_distance, Matrix, SafeBuffer
from memory import UnsafePointer
import benchmark

alias unit = benchmark.Unit.ns


fn run_levenshtein() raises -> Float64:
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

    @parameter
    fn bench():
        _ = levenshtein_distance(reference_split, text_split)

    var time = benchmark.run[bench](max_runtime_secs=0.5).mean(unit)

    return time


fn main() raises:
    # reference_split = List[String](
    #     String("w"),
    #     String("e"),
    #     String("r"),
    #     String("k"),
    #     String("i"),
    #     String("n"),
    #     String("g"),
    #     String("s"),
    #     String("p"),
    #     String("r"),
    #     String("i"),
    #     String("n"),
    #     String("c"),
    #     String("i"),
    #     String("p"),
    #     String("e"),
    # )

    # text_split = List[String](
    #     String("a"),
    #     String("a"),
    #     String("n"),
    #     String("b"),
    #     String("r"),
    #     String("a"),
    #     String("n"),
    #     String("d"),
    #     String("e"),
    #     String("n"),
    # )

    # @parameter
    # fn string_allocation():
    reference_split = List[StringLiteral](
        "w",
        "e",
        "r",
        "k",
        "i",
        "n",
        "g",
        "s",
        "p",
        "r",
        "i",
        "n",
        "c",
        "i",
        "p",
        "e",
    )

    text_split = List[StringLiteral](
        "a",
        "a",
        "n",
        "b",
        "r",
        "a",
        "n",
        "d",
        "e",
        "n",
    )

    @parameter
    fn bench():
        _ = levenshtein_distance(reference_split, text_split)

    # string_allocation_time = benchmark.run[string_allocation](
    #     max_runtime_secs=0.5
    # ).mean(unit)

    @parameter
    fn run_matrix_init():
        m = len(reference_split)
        n = len(text_split)

        cost_matrix = Matrix[Int](m + 1, n + 1, 0)

    @parameter
    fn run_safebuffer_init():
        m = len(reference_split)
        n = len(text_split)

        cost_matrix = SafeBuffer[Int](m + 1, n + 1)

    levenshtein_distance_time = benchmark.run[bench](max_runtime_secs=0.5).mean(
        unit
    )
    matrix_init_time = benchmark.run[run_matrix_init](
        max_runtime_secs=0.5
    ).mean(unit)

    # print("string allocation: ", str(string_allocation_time) + str(unit))
    print(
        "levenshtein distance total: ",
        str(levenshtein_distance_time) + str(unit),
    )
    print("matrix init: ", str(matrix_init_time) + str(unit))
    print(
        "safe buffer init: ",
        str(benchmark.run[run_safebuffer_init](max_runtime_secs=0.5).mean(unit))
        + str(unit),
    )
    # # bench = QuickBench()

    # # bench.run[List[StringLiteral], List[StringLiteral], Int](levenshtein_benchmark, bench_id=BenchId("bench_levenshtein"))

    # # bench.dump_report()
    # # Create a Bench instance
    # bench = Bench()

    # # Create a BenchId
    # bench_id = BenchId("my_benchmark")

    # # # Define input
    # test_input = 42

    # @parameter
    # fn bench_fn(inout b: Bencher, input: Int) capturing -> None:
    #     _ = input * 2

    # # # Run benchmark with input
    # bench.bench_with_input[Int, bench_fn](bench_id, test_input)

    # # Print results
    # bench.dump_report()

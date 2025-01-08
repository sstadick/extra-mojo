import math
from time import perf_counter_ns

alias nanoseconds_in_a_second = 1000000000.0
alias nanoseconds_in_a_microsecond = 1000
alias microseconds_in_a_second = 1000000
alias microseconds_in_a_millisecond = 1000


@value
struct Bench:
    var name: String
    var max_iterations: Int
    var warmup_iterations: Int
    # var func: fn () escaping raises

    # fn __init__(
    #     inout self,
    #     owned name: String,
    #     func: fn () raises -> None,
    #     max_iterations: Int = 1000,
    #     warmup_iterations: Int = 10,
    # ):
    #     self.name = name^
    #     self.max_iterations = max_iterations
    #     self.warmup_iterations = warmup_iterations
    #     self.func = func

    @staticmethod
    fn format_nice_time(time_in_ns: Float64) -> String:
        var microseconds = time_in_ns / nanoseconds_in_a_microsecond
        if microseconds > microseconds_in_a_second:
            return str(microseconds / microseconds_in_a_second) + " s"
        elif microseconds > microseconds_in_a_millisecond:
            return str(microseconds / microseconds_in_a_millisecond) + " ms"
        else:
            return str(microseconds) + " µs"

    fn benchmark[func: fn () capturing raises -> None](self) raises:
        print("========================================")
        print("Benchmarking ", self.name)
        print("Warming up... ", self.warmup_iterations, " iterations")
        var warmup_start = perf_counter_ns()
        for _ in range(self.warmup_iterations):
            func()
        var warmup_end = perf_counter_ns()
        print("--> ", self.format_nice_time(warmup_end - warmup_start))

        print("Measuring...")
        var super_begin = perf_counter_ns()
        var sum = 0.0
        var times = List[Float64]()
        var iterations = 0
        var five_seconds = 5.0 * nanoseconds_in_a_second
        var total_elapsed = 0.0
        while True:
            var begin = perf_counter_ns()
            func()
            var elapsed = perf_counter_ns() - begin
            times.append(elapsed)
            sum += elapsed
            iterations += 1
            total_elapsed += perf_counter_ns() - super_begin

            if (
                total_elapsed > five_seconds
                or iterations >= self.max_iterations
            ):
                break

        # Generate stats
        print(
            iterations, " iterations --> ", self.format_nice_time(total_elapsed)
        )

        var min = Float64.MAX
        var max = 0.0

        for time in times:
            if time[] > max:
                max = time[]
            if time[] < min:
                min = time[]
        var mean = sum / iterations

        var sum_of_dist_squared: Float64 = 0.0
        for time in times:
            sum_of_dist_squared += pow(time[] - mean, 2)

        var sigma = math.sqrt(sum_of_dist_squared / iterations)
        sort(times)
        var median = times[iterations // 2]

        print("\tMin: ", self.format_nice_time(min))
        print("\tMax: ", self.format_nice_time(max))
        print("\tMean: ", self.format_nice_time(mean))
        print("\tMedian: ", self.format_nice_time(median))
        print("\tStdDev: ", self.format_nice_time(sigma))
        print("========================================")

# frozen_string_literal: true

require "json"
COUNT = Integer(ENV.fetch("ROWS", "2000000"))
# rubocop:disable Migrations/SingleValueYielder -- Compare both APIs.
METHOD_YIELD = -> { Enumerator.new { |yielder| COUNT.times { |row| yielder.yield(row) } } }
# rubocop:enable Migrations/SingleValueYielder
PUSH = -> { Enumerator.new { |yielder| COUNT.times { |row| yielder << row } } }
Integer(ENV.fetch("ROUNDS", "11")).times do |round|
  variants = { yield: METHOD_YIELD, push: PUSH }
  variants = variants.to_a.reverse if round.odd?
  variants.each do |variant, build|
    GC.start
    count = 0
    allocated = GC.stat(:total_allocated_objects)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    build.call.each { count += 1 }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    raise unless count == COUNT
    puts JSON.generate(
           round:,
           variant:,
           wall: elapsed,
           allocations: GC.stat(:total_allocated_objects) - allocated,
         )
  end
end

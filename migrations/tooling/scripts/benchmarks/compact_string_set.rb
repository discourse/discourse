# frozen_string_literal: true

# Compares CompactStringSet membership against a plain Ruby Set — time and
# allocations for hits and misses (the shape from the scanner-branch review:
# 200k names, 100k lookups each way). The compact set trades one allocation
# per hit (the byte confirm) for GC-invisible, fork-stable storage; misses
# must stay allocation-free.
#
# Usage (from the repo root, under the core bundle):
#
#   cd migrations/core
#   bundle exec ruby ../tooling/scripts/benchmarks/compact_string_set.rb

require_relative "../../../core/lib/migrations/compact_string_set"

names = Array.new(200_000) { |i| "user_#{i}_#{(i * 2_654_435_761) % 1_000_000}" }
hits = names.sample(100_000, random: Random.new(42))
misses = Array.new(100_000) { |i| "missing_#{i}" }

def measure(label)
  GC.start
  allocations = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  found = yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  allocations = GC.stat(:total_allocated_objects) - allocations
  printf("%-24s %8.3f s  %12d allocations  (found %d)\n", label, elapsed, allocations, found)
end

compact = Migrations::CompactStringSet.new(names)
plain = Set.new(names)

measure("CompactStringSet hits") { hits.count { |name| compact.include?(name) } }
measure("CompactStringSet misses") { misses.count { |name| compact.include?(name) } }
measure("Set hits") { hits.count { |name| plain.include?(name) } }
measure("Set misses") { misses.count { |name| plain.include?(name) } }

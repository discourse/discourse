# frozen_string_literal: true

# to be used to compare ruby heaps generated in 2.1
# can isolate memory leaks
#
# rbtrace -p 15193 -e 'Thread.new{require "objspace"; ObjectSpace.trace_object_allocations_start; GC.start(full_mark: true); ObjectSpace.dump_all(output: File.open("heap.json","w"))}.join'
#
#
require 'set'
require 'json'

if ARGV.length != 2
  puts "Usage: diff_heaps [ORIG.json] [AFTER.json]"
  exit 1
end

origs = Set.new

File.open(ARGV[0], "r").each_line do |line|
  parsed = JSON.parse(line)
  origs << parsed["address"] if parsed && parsed["address"]
end

diff = []

File.open(ARGV[1], "r").each_line do |line|
  parsed = JSON.parse(line)
  if parsed && parsed["address"]
    diff << parsed unless origs.include? parsed["address"]
  end
end

diff.group_by do |x|
  [x["type"], x["file"], x["line"]]
end.map { |x, y|
  [x, y.count]
}.sort { |a, b|
  b[1] <=> a[1]
}.each { |x, y|
  puts "Leaked #{y} #{x[0]} objects at: #{x[1]}:#{x[2]}"
}

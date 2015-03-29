# using this script to try figure out why Ruby 2 is slower than 1.9
require 'flamegraph'

Flamegraph.generate('test.html', fidelity: 2) do
  require File.expand_path("../../config/environment", __FILE__)
end
exit

require 'memory_profiler'

result = MemoryProfiler.report do
  require File.expand_path("../../config/environment", __FILE__)
end
result.pretty_print

exit

require 'benchmark'

def profile_allocations(name)
  GC.disable
  initial_size = ObjectSpace.count_objects
  yield
  changes = ObjectSpace.count_objects
  changes.each do |k, _|
    changes[k] -= initial_size[k]
  end
  puts "#{name} changes"
  changes.sort{|a,b| b[1] <=> a[1]}.each do |a,b|
    next if b <= 0
    # 1 extra hash for tracking
    puts "#{a} #{a == :T_HASH ? b-1 : b}"
  end
  GC.enable
end

def profile(name, &block)
  puts "Profiling all object allocation for #{name}"
  GC.start
  GC.disable

  items = []
  objs = []

  ObjectSpace.trace_object_allocations do
    block.call

    ObjectSpace.each_object do |o|
      objs << o
    end

    objs.each do |o|
      g = ObjectSpace.allocation_generation(o)
      if g
        l = ObjectSpace.allocation_sourceline(o)
        f = ObjectSpace.allocation_sourcefile(o)
        c = ObjectSpace.allocation_class_path(o)
        m = ObjectSpace.allocation_method_id(o)
        items << "Allocated #{c} in #{m} #{f}:#{l}"
      end
    end
  end

  items.group_by{|x| x}.sort{|a,b| b[1].length <=> a[1].length}.each do |row, group|
    puts "#{row} x #{group.length}"
  end

  GC.enable
  profile_allocations(name, &block)
end



def stuff
  u = User.first
  r = TopicQuery.new(u, {}).list_latest
  r.topics.to_a
end

stuff
profile_allocations "stuff" do
  stuff
end


# Benchmark.bmbm do |x|
# 
#   x.report("find") do
#     100.times{stuff}
#   end
# 
# end
# 
#   x.report("grab 10 users id") do
#     100.times{User.limit(10).select(:id).to_a}
#   end
# 
#   x.report("grab 10 users") do
#     100.times{User.limit(10).to_a}
#   end
# 
# profile("topic query") do
# r = TopicQuery.new(u, {}).list_latest
# r.topics.to_a
# end

# 
# RubyProf.start
# 
# r = TopicQuery.new(u, {}).list_latest
# r.topics.to_a
# 
# result = RubyProf.stop
# printer = RubyProf::GraphPrinter.new(result)
# # printer = RubyProf::FlatPrinter.new(result)
# printer.print(STDOUT, :min_percent => 2)
# 
# exit
# 
# # User.limit(10).to_a
# User.limit(10).select(:created_at).to_a
# 
# profile("limit 10") do
#   User.limit(10).select(:created_at).to_a
# end
# 
# exit
# User.limit(10).to_a
# exit
#
# User.select('id, 2 bob').first
# Benchmark.bmbm do |x|
# 
#   x.report("find") do
#     100.times{User.find(1)}
#   end
# 
#   x.report("grab 10 users created_at") do
#     100.times{User.limit(10).select(:created_at).to_a}
#   end
# 
#   x.report("grab 10 users id") do
#     100.times{User.limit(10).select(:id).to_a}
#   end
# 
#   x.report("grab 10 users") do
#     100.times{User.limit(10).to_a}
#   end
# 
# 
#   x.report("pg direct grab 10 users") do
#     100.times do
#       r = ActiveRecord::Base.connection.raw_connection.async_exec("select * from users limit 10")
#       r.fields.each_with_index do |f,i|
#         r.ftype(i)
#       end
#       r.each_row do |x|
#         x
#       end
#     end
#   end
# 
# end
# 

# profile("find") do
#   User.find(1)
# end
# puts
# profile("where") do
#   User.where(id: 1).first
# end


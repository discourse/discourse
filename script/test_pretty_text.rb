# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

puts PrettyText.cook "test"
1000.times do |i|
  # PrettyText.v8.eval <<~JS
  #   window.markdownit().render('test');
  # JS
  PrettyText.cook "test"

  PrettyText.v8.eval('gc()')

  # if i % 500 == 0
  #p PrettyText.v8.heap_stats
  # end
end

# sam@ubuntu script % ruby test_pretty_text.rb
# {:total_physical_size=>10556240, :total_heap_size_executable=>5242880, :total_heap_size=>16732160, :used_heap_size=>7483336, :heap_size_limit=>1501560832}
# {:total_physical_size=>288670880, :total_heap_size_executable=>6291456, :total_heap_size=>292507648, :used_heap_size=>252365360, :heap_size_limit=>1501560832}
# {:total_physical_size=>543060056, :total_heap_size_executable=>6291456, :total_heap_size=>548360192, :used_heap_size=>503699768, :heap_size_limit=>1501560832}
# {:total_physical_size=>793401560, :total_heap_size_executable=>6291456, :total_heap_size=>801067008, :used_heap_size=>739517840, :heap_size_limit=>1501560832}
# {:total_physical_size=>1045932696, :total_heap_size_executable=>6291456, :total_heap_size=>1055870976, :used_heap_size=>992549688, :heap_size_limit=>1501560832}
# {:total_physical_size=>1298442008, :total_heap_size_executable=>6291456, :total_heap_size=>1309626368, :used_heap_size=>1224681072, :heap_size_limit=>1501560832}

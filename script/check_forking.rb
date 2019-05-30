# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

def pretty
  puts "<before>"
  puts PrettyText.cook("My pid is #{Process.pid}")
  GC.start
  sleep 1
  puts "done gc"
end

Discourse.after_fork
pretty

child = fork do
  Discourse.after_fork
  pretty
  grand_child = fork do
    Discourse.after_fork
    pretty
    puts "try to exit"
    Process.kill "KILL", Process.pid
  end
  puts "before wait 2"
  Process.wait grand_child
  puts "after wait 2"
  Process.kill "KILL", Process.pid
end

puts "before wait 1"
Process.wait child
puts "after wait 1"

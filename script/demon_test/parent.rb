# frozen_string_literal: true

require File.expand_path("../../../config/environment", __FILE__)

puts "Parent is now loaded"

class ForkExecDemon < Demon::Base
  def self.prefix
    "fork-exec-child"
  end

  def run
    if @pid = fork
      write_pid_file
      return
    end

    exec "./child #{parent_pid}"
  end
end

ForkExecDemon.start(1, verbose: true)

while true
  ForkExecDemon.ensure_running
  sleep 0.1
end

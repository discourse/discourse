# frozen_string_literal: true

require "discourse_vips/worker"
require "socket"

if ENV["DISCOURSE_VIPS_TEST_WITHOUT_LANDLOCK"]
  Landlock.singleton_class.define_method(:supported?) { false }
end

module TestOperations
  def warm
    tasks_before = native_task_count
    super
    @runtime = {
      rails: Object.const_defined?(:Rails),
      bundler: Object.const_defined?(:Bundler),
      rubygems: Object.const_defined?(:Gem),
      landlock: Landlock.supported?,
      ruby_threads: Thread.list.size,
      native_tasks_before: tasks_before,
      native_tasks_after: native_task_count,
    }
  end

  def call(command)
    operation, *arguments = command

    case operation
    when "test-landlock"
      Landlock.supported?.to_s
    when "test-runtime"
      MessagePack.pack(@runtime.merge(operation_pid: Process.pid, worker_pid: Process.ppid))
    when "test-return"
      arguments.fetch(0)
    when "test-block"
      marker_path, release_path, value = arguments
      File.write(marker_path, Process.pid)
      sleep 0.001 until File.exist?(release_path)
      value
    when "test-crash"
      Process.kill("KILL", Process.pid)
    when "test-read"
      File.read(arguments.fetch(0))
    when "test-network"
      socket = Socket.new(:INET, :STREAM)
      socket.close
      "allowed"
    else
      super
    end
  end

  private

  def native_task_count
    Dir.children("/proc/self/task").size if File.directory?("/proc/self/task")
  end
end

DiscourseVips::Operations.singleton_class.prepend(TestOperations)
load File.expand_path("../../../script/discourse_vips_worker", __dir__)

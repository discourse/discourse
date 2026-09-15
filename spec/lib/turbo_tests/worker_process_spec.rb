# frozen_string_literal: true

require "rbconfig"
require "timeout"
require_relative "../../../lib/turbo_tests/worker_process"

RSpec.describe TurboTests::WorkerProcess do
  describe "#value" do
    before do
      unless RUBY_PLATFORM.include?("linux") && File.directory?("/proc/self")
        skip "Worker process cleanup requires Linux /proc"
      end
    end

    it "closes inherited output pipes after a worker crashes with a surviving child" do
      code = <<~RUBY
        child = Process.spawn(#{RbConfig.ruby.inspect}, "-e", "sleep 120")
        puts child
        STDOUT.flush
        exit! 17
      RUBY
      worker = described_class.new(environment: {}, command: [RbConfig.ruby, "-e", code])
      worker.stdin.close

      output, errors, status =
        Timeout.timeout(5) { [worker.stdout.read, worker.stderr.read, worker.value] }

      expect(status.exitstatus).to eq(17)
      expect(errors).to eq("")
      child_pid = Integer(output.strip)
      Timeout.timeout(5) do
        loop do
          begin
            state = File.read("/proc/#{child_pid}/stat").rpartition(")").last.split.first
            break if state == "Z" || state == "X"
          rescue Errno::ENOENT
            break
          end
          sleep 0.01
        end
      end
      expect(worker.alive?).to eq(false)
    ensure
      worker&.signal("KILL", groups: true)
      [worker&.stdin, worker&.stdout, worker&.stderr].compact.each do |io|
        io.close unless io.closed?
      end
    end
  end
end

# frozen_string_literal: true

require "demon/base"

RSpec.describe Demon::Base do
  let(:demon_class) do
    Class.new(described_class) do
      def self.prefix
        "test_demon"
      end

      attr_reader :runs

      # Stands in for the forked process.
      def run
        @runs = (@runs || 0) + 1
        @pid = Process.spawn("sleep", "600")
        write_pid_file
      end

      def stop_timeout
        2
      end
    end
  end

  let(:pid_file) { Rails.root.join("tmp/pids/test_demon_0.pid").to_s }
  let(:spawned) { [] }

  before { FileUtils.mkdir_p(File.dirname(pid_file)) }

  after do
    [*spawned, File.exist?(pid_file) && File.read(pid_file).to_i].compact.uniq.each do |pid|
      Process.kill("KILL", pid)
      Process.waitpid(pid)
    rescue StandardError
      nil
    end
    FileUtils.rm_f(pid_file)
  end

  # A previous instance that takes `delay` seconds to exit after TERM.
  def previous_instance(delay:)
    pid = Process.spawn(RbConfig.ruby, "-e", "trap('TERM') { sleep #{delay}; exit }; sleep")
    spawned << pid
    File.write(pid_file, pid)
    sleep 0.3 # let it install its TERM handler
    pid
  end

  def wait_until(timeout: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "timed out" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end

  describe "#start" do
    it "starts right away when no previous instance is running" do
      demon = demon_class.new(0)
      demon.start

      expect(demon.runs).to eq(1)
      expect(described_class.running?(demon.pid)).to eq(true)
    end

    it "starts the replacement only after the previous instance has exited" do
      previous = previous_instance(delay: 0.5)
      demon = demon_class.new(0)

      demon.start
      expect(demon.pid).to eq(nil)

      demon.ensure_running
      demon.start

      wait_until { demon.pid }
      expect(described_class.running?(previous)).to eq(false)
      expect(demon.runs).to eq(1)
    end

    it "kills a previous instance that doesn't exit within the stop timeout" do
      previous = previous_instance(delay: 600)
      demon = demon_class.new(0)

      demon.start

      wait_until { demon.pid }
      expect(described_class.running?(previous)).to eq(false)
    end
  end

  describe ".running?" do
    it "treats a process that vanishes while being checked as gone" do
      File.stubs(:read).with("/proc/123/stat").raises(Errno::ESRCH)

      expect(described_class.running?(123)).to eq(false)
    end

    it "treats a zombie as gone" do
      pid = Process.spawn("true")
      wait_until { File.read("/proc/#{pid}/stat").split(") ").last.start_with?("Z") }

      expect(described_class.alive?(pid)).to eq(true)
      expect(described_class.running?(pid)).to eq(false)
    ensure
      Process.waitpid(pid) if pid
    end
  end
end

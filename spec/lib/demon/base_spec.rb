# frozen_string_literal: true

require "demon/base"

RSpec.describe Demon::Base do
  let(:demon_class) do
    Class.new(described_class) do
      def self.prefix
        "test_demon"
      end

      attr_reader :runs

      # Stand-in for the forked Discourse process.
      def run
        return super if keeper_managed?

        @runs = (@runs || 0) + 1
        @pid = Process.spawn("sleep", "600")
        write_pid_file
      end
    end
  end

  let(:pid_file) { Rails.root.join("tmp/pids/test_demon_0.pid").to_s }
  let!(:previous_pid) { Process.spawn("sleep", "600") }

  before { File.write(pid_file, previous_pid) }

  after do
    described_class.handoff_supervisor_pid = nil
    [previous_pid, File.exist?(pid_file) && File.read(pid_file).to_i].compact.uniq.each do |pid|
      Process.kill("KILL", pid)
      Process.waitpid(pid)
    rescue StandardError
      nil
    end
    FileUtils.rm_f(pid_file)
  end

  def wait_until(timeout: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "timed out" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end

  describe "#start" do
    it "kills a leftover process before starting when not handing off" do
      demon = demon_class.new(0)
      demon.start

      wait_until { Process.waitpid(previous_pid, Process::WNOHANG) }
      expect(demon.runs).to eq(1)
    end

    it "starts the replacement before stopping the previous process when handing off" do
      described_class.handoff_supervisor_pid = Process.pid
      demon = demon_class.new(0)
      demon.stubs(:stop_timeout).returns(5)

      demon.start

      expect(File.read(pid_file).to_i).to eq(demon.pid)
      expect(described_class.running?(demon.pid)).to eq(true)
      wait_until { Process.waitpid(previous_pid, Process::WNOHANG) }
    end

    it "leaves a running server-lifetime process to the service keeper" do
      described_class.handoff_supervisor_pid = Process.pid
      ServiceKeeper.stubs(:enabled?).returns(true)
      demon = demon_class.new(0)
      demon.stubs(:server_lifetime_spec).returns({ "argv" => %w[sleep 600] })
      ServiceKeeper
        .expects(:ensure_running)
        .with("test_demon_0", { "argv" => %w[sleep 600] })
        .returns(previous_pid)

      demon.start

      expect(demon.pid).to eq(previous_pid)
      expect(described_class.running?(previous_pid)).to eq(true)
    end
  end

  describe ".running?" do
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

# frozen_string_literal: true

require "demon/base"

RSpec.describe Demon::Base do
  let(:demon_class) do
    Class.new(described_class) do
      def self.prefix
        "test_demon"
      end

      def stop_signal
        "KILL"
      end

      def stop_timeout
        1
      end

      def after_fork
        sleep
      end
    end
  end

  let(:directory) { Dir.mktmpdir }
  let(:demon) { demon_class.new(0, rails_root: "#{directory}/") }
  let(:spawned) { [] }
  let(:pipes) { [] }

  after do
    demon.stop
    spawned.each do |pid|
      Process.kill("KILL", pid)
      Process.waitpid(pid)
    rescue Errno::ESRCH, Errno::ECHILD
    end
    pipes.each { |pipe| pipe.close unless pipe.closed? }
    FileUtils.remove_entry(directory)
  end

  def previous_instance(ignore_term: false)
    ready_reader, ready_writer = IO.pipe
    release_reader, release_writer = IO.pipe
    pipes.concat([ready_reader, ready_writer, release_reader, release_writer])
    handler = ignore_term ? "nil" : "STDIN.read(1); exit"
    pid =
      Process.spawn(
        RbConfig.ruby,
        "-e",
        "trap('TERM') { #{handler} }; STDOUT.puts('ready'); STDOUT.flush; sleep",
        in: release_reader,
        out: ready_writer,
      )
    spawned << pid
    ready_writer.close
    release_reader.close
    expect(ready_reader.gets).to eq("ready\n")
    FileUtils.mkdir_p(File.dirname(demon.pid_file))
    File.write(demon.pid_file, pid)
    [pid, release_writer]
  end

  describe "#start" do
    it "starts immediately when no previous instance is running" do
      demon.start

      expect(described_class.running?(demon.pid)).to eq(true)
      expect(File.read(demon.pid_file).to_i).to eq(demon.pid)
    end

    it "waits for the previous instance to exit without blocking the caller" do
      previous, release = previous_instance

      demon.start

      expect(demon.pid).to eq(nil)
      expect(described_class.running?(previous)).to eq(true)
      release.write("x")
      wait_for(timeout: 5) { demon.pid && File.read(demon.pid_file).to_i == demon.pid }
      expect(described_class.running?(previous)).to eq(false)
      expect(File.read(demon.pid_file).to_i).to eq(demon.pid)
    end

    it "kills a previous instance that exceeds the stop timeout" do
      previous_instance(ignore_term: true)

      demon.start

      wait_for(timeout: 5) { demon.pid && File.read(demon.pid_file).to_i == demon.pid }
      expect(described_class.running?(spawned.first)).to eq(false)
    end
  end

  describe "#ensure_running" do
    it "keeps one replacement while the previous instance is stopping" do
      _previous, release = previous_instance
      demon.start

      demon.ensure_running
      demon.start
      release.write("x")

      wait_for(timeout: 5) { demon.pid && File.read(demon.pid_file).to_i == demon.pid }
      replacement = demon.pid
      demon.ensure_running
      expect(demon.pid).to eq(replacement)
      expect(File.read(demon.pid_file).to_i).to eq(replacement)
    end
  end

  describe ".running?" do
    it "treats a process that vanishes while being checked as gone" do
      File.stubs(:read).with("/proc/123/stat").raises(Errno::ESRCH)

      expect(described_class.running?(123)).to eq(false)
    end

    it "treats an unreaped exited process as stopped" do
      pid = Process.spawn("true")
      spawned << pid
      wait_for { File.read("/proc/#{pid}/stat").split(") ").last.start_with?("Z") }

      expect(described_class.alive?(pid)).to eq(true)
      expect(described_class.running?(pid)).to eq(false)
    end
  end
end

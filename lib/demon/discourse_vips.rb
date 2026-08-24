# frozen_string_literal: true

require "demon/base"
require "discourse_vips"

class Demon::DiscourseVips < Demon::Base
  START_TIMEOUT_SECONDS = 5
  private_constant :START_TIMEOUT_SECONDS

  def self.prefix
    "discourse_vips"
  end

  def self.wait_until_ready
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + START_TIMEOUT_SECONDS
    broker_pid = demons.fetch("#{prefix}_0").pid
    loop do
      begin
        if File.socket?(::DiscourseVips.socket_path) &&
             ::DiscourseVips.version(expected_broker_pid: broker_pid)
          return
        end
      rescue ::DiscourseVips::Error
      end

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise "DiscourseVips broker did not start"
      end

      sleep 0.01
    end
  end

  def run
    Discourse.before_fork
    ready_reader, ready_writer = IO.pipe
    @pid =
      fork do
        ready_writer.close
        exit! 1 if ready_reader.read(1) != "1"
        ready_reader.close
        Process.setproctitle("discourse #{self.class.prefix}")
        establish_app
        after_fork
      end
    ready_reader.close
    write_pid_file
    ready_writer.write("1")
  ensure
    ready_reader&.close unless ready_reader&.closed?
    ready_writer&.close unless ready_writer&.closed?
  end

  def after_fork
    require "discourse_vips/broker"
    ::DiscourseVips::Broker.new(parent_pid:).run
  ensure
    remove_owned_pid_file
  end

  private

  def establish_app
    ObjectSpace
      .each_object(IO)
      .to_a
      .each do |io|
        next if io.closed? || io.fileno <= 2

        io.close
      rescue IOError
      end

    Signal.trap("HUP") { Process.kill("TERM", Process.pid) }
  end

  def remove_owned_pid_file
    FileUtils.rm_f(pid_file) if File.read(pid_file).to_i == Process.pid
  rescue Errno::ENOENT
  end
end

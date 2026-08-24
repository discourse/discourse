# frozen_string_literal: true

require "demon/base"
require "discourse_vips"
require "rbconfig"

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
    ready_reader, ready_writer = IO.pipe
    @pid =
      fork do
        ready_writer.close
        exit! 1 if ready_reader.read(1) != "1"
        ready_reader.close
        exec_broker
      end
    ready_reader.close
    write_pid_file
    ready_writer.write("1")
  ensure
    ready_reader&.close unless ready_reader&.closed?
    ready_writer&.close unless ready_writer&.closed?
  end

  private

  def exec_broker
    environment = { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }
    entrypoint = File.join(@rails_root, "script", "discourse_vips_broker")
    Process.exec(
      environment,
      RbConfig.ruby,
      entrypoint,
      ::DiscourseVips.socket_path,
      parent_pid.to_s,
      pid_file,
      File.join(@rails_root, "Gemfile"),
      close_others: true,
    )
  rescue StandardError
    ::DiscourseVips.remove_owned_pid_file(pid_file)
    raise
  end
end

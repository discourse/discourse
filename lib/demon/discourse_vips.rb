# frozen_string_literal: true

require "demon/base"
require "discourse_vips"

class Demon::DiscourseVips < Demon::Base
  def self.prefix
    "discourse_vips"
  end

  def self.start(verbose: false, logger: nil)
    ::DiscourseVips::Client.use_shared_worker
    super(1, verbose:, logger:)
    ::DiscourseVips.version
  rescue StandardError
    stop
    raise
  end

  def self.release_inherited_worker
    demons&.each_value(&:release_inherited_worker)
  end

  def run
    @worker_process&.discard
    @worker_process =
      ::DiscourseVips::WorkerProcess.new(
        socket_path: ::DiscourseVips::WorkerProcess.shared_socket_path,
      )
    @pid = @worker_process.pid
    write_pid_file
  rescue StandardError
    @worker_process&.shutdown
    @worker_process = nil
    @pid = nil
    @started = false
    raise
  end

  def stop
    worker_pid = @pid
    @started = false
    @worker_process&.shutdown
  ensure
    @worker_process = nil
    @pid = nil
    delete_pid_file(worker_pid)
  end

  def release_inherited_worker
    @worker_process&.discard
    @worker_process = nil
  end

  private

  def delete_pid_file(worker_pid)
    return if !worker_pid || !File.exist?(pid_file)
    return if File.read(pid_file).to_i != worker_pid

    File.delete(pid_file)
  rescue SystemCallError
  end
end

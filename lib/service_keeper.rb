# frozen_string_literal: true

require "json"
require "socket"

# Client for script/discourse_service_keeper, which runs server-lifetime
# services (processes that hold no Discourse heap and must not restart when
# pitchfork reforks) on behalf of whichever service worker is current.
#
# Only enabled when reforking is on and a supervisor process is known; the
# keeper exits, stopping its services, once that supervisor is gone.
module ServiceKeeper
  class Error < StandardError
  end

  SPAWN_TIMEOUT_SECONDS = 10

  class << self
    attr_reader :supervisor_pid

    def enable!(supervisor_pid:)
      @supervisor_pid = supervisor_pid
    end

    def disable!
      @supervisor_pid = nil
    end

    def enabled?
      !@supervisor_pid.nil?
    end

    def socket_path
      Rails.root.join("tmp/pids/discourse_service_keeper.sock").to_s
    end

    # Starts the named service with `spec` unless the keeper already runs it
    # with an identical spec. Returns its pid.
    #
    # spec keys (JSON): argv, env, chdir, unsetenv_others, and optionally
    # unix_listener (path the keeper listens on, passed as "%{listener_fd}")
    # and owner_pipe (a pipe the keeper holds open, passed as "%{owner_fd}").
    def ensure_running(name, spec)
      request({ "command" => "ensure", "name" => name, "spec" => spec }).fetch("pid")
    end

    def stop(name)
      request({ "command" => "stop", "name" => name })
    end

    def status
      request({ "command" => "status" })
    end

    private

    def request(payload, spawn_if_missing: true)
      response =
        UNIXSocket.open(socket_path) do |socket|
          socket.puts(payload.to_json)
          JSON.parse(socket.gets.to_s)
        end
      raise Error, response["error"] if response["error"]
      response
    rescue Errno::ENOENT, Errno::ECONNREFUSED
      raise Error, "service keeper is not running" if !spawn_if_missing
      spawn_keeper
      request(payload, spawn_if_missing: false)
    end

    def spawn_keeper
      raise Error, "service keeper is not enabled" if !enabled?

      pid =
        Process.spawn(
          RbConfig.ruby,
          "--disable-gems",
          Rails.root.join("script/discourse_service_keeper").to_s,
          socket_path,
          supervisor_pid.to_s,
          in: File::NULL,
          pgroup: true,
        )
      Process.detach(pid)

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SPAWN_TIMEOUT_SECONDS
      until File.socket?(socket_path)
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise Error, "service keeper did not start"
        end
        sleep 0.05
      end
    end
  end
end

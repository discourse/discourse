require "drb/drb"
require "autospec/rspec_runner"

module Autospec

  class SporkRunner < RspecRunner

    def start
      if already_running?(pid_file)
        puts "autospec appears to be running, it is possible the pid file is old"
        puts "if you are sure it is not running, delete #{pid_file}"
        return
      end
      write_pid_file(pid_file, Process.pid)
      start_spork
      @spork_running = true
    end

    def running?
      # launch a thread that will wait for spork to die
      @monitor_thread ||=
        Thread.new do
          Process.wait(@spork_pid)
          @spork_running = false
        end

      @spork_running
    end

    def run(specs)
      args = ["-r", "#{File.dirname(__FILE__)}/formatter.rb",
              "-f", "Autospec::Formatter", specs.split].flatten
      spork_service.run(args,$stderr,$stdout)
    end

    def reload
      stop_spork
      sleep 1
      start_spork
    end

    def abort
      spork_service.abort
    end

    def stop
      stop_spork
    end

    private

    def spork_pid_file
      Rails.root + "tmp/pids/spork.pid"
    end

    def pid_file
      Rails.root + "tmp/pids/autospec.pid"
    end

    def already_running?(pid_file)
      if File.exists? pid_file
        pid = File.read(pid_file).to_i
        Process.getpgid(pid) rescue nil
      end
    end

    def write_pid_file(file, pid)
      FileUtils.mkdir_p(Rails.root + "tmp/pids")
      File.open(file,'w') do |f|
        f.write(pid)
      end
    end

    def spork_running?
      spork_service.port rescue nil
    end

    def spork_service
      unless @drb_listener_running
        begin
          DRb.start_service("druby://127.0.0.1:0")
        rescue SocketError, Errno::EADDRNOTAVAIL
          DRb.start_service("druby://:0")
        end
        @drb_listener_running = true
      end

      @spork_service ||= DRbObject.new_with_uri("druby://127.0.0.1:8989")
    end

    def start_spork
      if already_running?(spork_pid_file)
        puts "Killing old orphan spork instance"
        stop_spork
        sleep 1
      end

      @spork_pid = Process.spawn({'RAILS_ENV' => 'test'}, "bundle exec spork")
      write_pid_file(spork_pid_file, @spork_pid)

      running = false
      while !running
        running = spork_running?
        sleep 0.01
      end
    end

    def stop_spork
      pid = File.read(spork_pid_file).to_i
      Process.kill("SIGTERM", pid) rescue nil
    end

  end

end

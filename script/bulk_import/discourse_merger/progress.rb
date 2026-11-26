# frozen_string_literal: true

require "time"

module BulkImport::DiscourseMerge
  class Progress
    attr_reader :stage
    attr_writer :recovery_run

    def initialize(output: $stdout)
      @output = output
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def open_log(directory, command)
      directory = Pathname.new(directory).join("logs")
      directory.mkpath
      File.chmod(0o700, directory)
      @path =
        directory.join(
          "#{command}-#{Time.now.utc.strftime("%Y%m%dT%H%M%S%6NZ")}-#{Process.pid}.log",
        )
      @log = @path.open(File::WRONLY | File::CREAT | File::EXCL, 0o600)
      say("Log: #{@path}")
    end

    def start(stage)
      @stage = stage
      say("Starting #{stage}")
    end

    def say(message)
      line = timestamp(message)
      [@log, @output].compact.each do |stream|
        stream.puts(line)
        stream.flush
      end
    end

    def failed(error, output: $stderr)
      message = error.is_a?(Interrupt) ? "Interrupted" : error.message
      line = timestamp("Failed during #{@stage || "command setup"}: #{message}")
      output.puts(@path ? "#{line}\nLog: #{@path}" : line)
      guidance =
        if @recovery_run
          "Keep #{@recovery_run} and recover the destination PostgreSQL, local storage, and Redis baseline before applying from a new project."
        else
          "Correct the reported input or setup and rerun the command."
        end
      output.puts(guidance)
      @log&.puts(line, guidance, *error.backtrace)
    end

    def close
      @log&.close
    end

    private

    def timestamp(message)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started
      format("[%0.1fs] %s", elapsed, message)
    end
  end
end

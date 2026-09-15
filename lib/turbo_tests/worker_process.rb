# frozen_string_literal: true

module TurboTests
  class WorkerProcess
    attr_reader :stdin, :stdout, :stderr, :pid

    def initialize(environment:, command:)
      unless RUBY_PLATFORM.include?("linux") && File.directory?("/proc/self")
        raise "Dynamic scheduling requires Linux /proc"
      end

      input, @stdin = IO.pipe
      @stdout, output = IO.pipe
      @stderr, errors = IO.pipe
      @mutex = Mutex.new
      @pid = Process.spawn(environment, *command, in: input, out: output, err: errors, pgroup: true)
      @reserved = true
      [input, output, errors].each(&:close)
      @waiter =
        Thread.new do
          status = nil
          begin
            loop do
              state = File.read("/proc/#{@pid}/stat").rpartition(")").last.split.first
              break if state == "Z" || state == "X"
              sleep 0.05
            end
          ensure
            status = terminate_and_reap
          end
          status
        end
    rescue StandardError
      terminate_and_reap if @reserved
      [input, @stdin, @stdout, output, @stderr, errors].compact.each do |io|
        io.close unless io.closed?
      end
      raise
    end

    def alive?
      @waiter.alive?
    end

    def value
      @waiter.value
    end

    def signal(signal, groups:)
      @mutex.synchronize { Process.kill(signal, groups ? -@pid : @pid) if @reserved }
    rescue Errno::ESRCH
    end

    private

    def terminate_and_reap
      @mutex.synchronize do
        return unless @reserved
        begin
          Process.kill("KILL", -@pid)
        rescue Errno::ESRCH
        ensure
          begin
            status = Process.waitpid2(@pid).last
          ensure
            @reserved = false
          end
        end
        status
      end
    end
  end
end

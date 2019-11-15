# frozen_string_literal: true

class Thread
  attr_accessor :origin
end

class ThreadDetective
  def self.test_thread
    Thread.new { sleep 1 }
  end
  def self.start(max_threads)
    @thread ||= Thread.new do
      self.new.monitor(max_threads)
    end

    @trace = TracePoint.new(:thread_begin) do |tp|
      Thread.current.origin = Thread.current.inspect
    end
    @trace.enable
  end

  def self.stop
    @thread&.kill
    @thread = nil
    @trace&.disable
    @trace.stop
  end

  def monitor(max_threads)
    STDERR.puts "Monitoring threads in #{Process.pid}"

    while true
      threads = Thread.list

      if threads.length > max_threads
        str = +("-" * 60)
        str << "#{threads.length} found in Process #{Process.pid}!\n"

        threads.each do |thread|
          str << "\n"
          if thread.origin
            str << thread.origin
          else
            str << thread.inspect
          end
          str << "\n"
        end
        str << ("-" * 60)

        STDERR.puts str
      end
      sleep 1
    end
  end

end

module Autospec
  class SimpleRunner < BaseRunner

    def abort
      if @pid
        Process.kill("SIGINT", @pid) rescue nil
        while(Process.getpgid(@pid) rescue nil)
          sleep 0.001
        end
        @pid = nil
      end
    end

    def run(args, spec)
      self.abort
      puts "Running: " << spec
      @pid = Process.spawn({"RAILS_ENV" => "test"}, "bundle exec rspec " << args.join(" "))
      pid, status = Process.wait2(@pid)
      status
    end

    def stop
      self.abort
    end
  end
end

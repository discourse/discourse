require "autospec/rspec_runner"

module Autospec

  class SimpleRunner < RspecRunner

    def run(specs)
      puts "Running Rspec: " << specs
      # kill previous rspec instance
      self.abort
      # we use our custom rspec formatter
      args = ["-r", "#{File.dirname(__FILE__)}/formatter.rb",
              "-f", "Autospec::Formatter", specs.split].flatten.join(" ")
      # launch rspec
      Dir.chdir(Rails.root) do
        env = { "RAILS_ENV" => "test" }
        if specs.split(' ').any? { |s| s =~ /^(.\/)?plugins/ }
          env["LOAD_PLUGINS"] = "1"
          puts "Loading plugins while running specs"
        end
        @pid = Process.spawn(env, "bin/rspec #{args}")
        _, status = Process.wait2(@pid)
        status.exitstatus
      end
    end

    def abort
      if @pid
        Process.kill("INT", @pid) rescue nil
        while (Process.getpgid(@pid) rescue nil)
          sleep 0.001
        end
        @pid = nil
      end
    end

    def stop
      abort
    end

  end

end

require 'autospec/rspec_runner'

module Autospec
  class SimpleRunner < RspecRunner
    def initialize
      @mutex = Mutex.new
    end

    def run(specs)
      puts 'Running Rspec: ' << specs
      # kill previous rspec instance
      @mutex.synchronize { self.abort }
      # we use our custom rspec formatter
      args =
        [
          '-r',
          "#{File.dirname(__FILE__)}/formatter.rb",
          '-f',
          'Autospec::Formatter',
          specs.split
        ]
          .flatten
          .join(' ')
      # launch rspec
      Dir.chdir(Rails.root) do
        env = { 'RAILS_ENV' => 'test' }
        if specs.split(' ').any? { |s| s =~ %r{^(.\/)?plugins} }
          env['LOAD_PLUGINS'] = '1'
          puts 'Loading plugins while running specs'
        end
        pid =
          @mutex.synchronize { @pid = Process.spawn(env, "bin/rspec #{args}") }

        _, status = Process.wait2(pid)

        status.exitstatus
      end
    end

    def abort
      if pid = @pid
        begin
          Process.kill('TERM', pid)
        rescue StandardError
          nil
        end
        wait_for_done(pid)
        pid = nil
      end
    end

    def stop
      # assume sigint on child will take care of this?
      wait_for_done(pid) if pid = @pid
    end

    def wait_for_done(pid)
      i = 3000
      while (
        begin
          i > 0 && Process.getpgid(pid)
        rescue StandardError
          nil
        end
      )
        sleep 0.001
        i -= 1
      end

      if (
         begin
           Process.getpgid(pid)
         rescue StandardError
           nil
         end
       )
        STDERR.puts "Terminating rspec #{pid} by force cause it refused graceful termination"
        Process.kill('KILL', pid)
      end
    end
  end
end

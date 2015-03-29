require "demon/rails_autospec"

module Autospec

  class QunitRunner < BaseRunner

    WATCHERS = {}
    def self.watch(pattern, &blk); WATCHERS[pattern] = blk; end
    def watchers; WATCHERS; end

    # Discourse specific
    watch(%r{^app/assets/javascripts/discourse/(.+)\.js$}) { |m| "test/javascripts/#{m[1]}_test.js" }
    watch(%r{^app/assets/javascripts/admin/(.+)\.js$})     { |m| "test/javascripts/admin/#{m[1]}_test.js" }
    watch(%r{^test/javascripts/.+\.js$})

    RELOADERS = Set.new
    def self.reload(pattern); RELOADERS << pattern; end
    def reloaders; RELOADERS; end

    # Discourse specific
    reload(%r{^test/javascripts/fixtures/.+_fixtures\.js$})
    reload(%r{^test/javascripts/(helpers|mixins)/.+\.js$})
    reload("test/javascripts/test_helper.js")

    require "socket"

    class PhantomJsNotInstalled < StandardError; end

    def initialize
      ensure_phantomjs_is_installed
    end

    def start
      # ensure we can launch the rails server
      unless port_available?(port)
        puts "Port #{port} is not available"
        puts "Either kill the process using that port or use the `TEST_SERVER_PORT` environment variable"
        return
      end

      # start rails
      start_rails_server
      @running = true
    end

    def running?
      @running
    end

    def run(specs)
      puts "Running Qunit: #{specs}"

      abort

      qunit_url = "http://localhost:#{port}/qunit"

      if specs != "spec" && specs.split.length == 1
        module_name = try_to_find_module_name(specs.strip)
        qunit_url << "?module=#{module_name}" if module_name
      end

      cmd = "phantomjs #{Rails.root}/lib/autospec/run-qunit.js \"#{qunit_url}\""

      @pid = Process.spawn(cmd)
      _, status = Process.wait2(@pid)

      status.exitstatus
    end

    def reload
      stop_rails_server
      sleep 1
      start_rails_server
    end

    def abort
      if @pid
        children_processes(@pid).each { |pid| kill_process(pid) }
        kill_process(@pid)
        @pid = nil
      end
    end

    def failed_specs
      specs = []
      path = './tmp/qunit_result'
      specs = File.readlines(path) if File.exist?(path)
      specs
    end

    def stop
      # kill phantomjs first
      abort
      stop_rails_server
      @running = false
    end

    private

    def ensure_phantomjs_is_installed
      raise PhantomJsNotInstalled.new unless system("command -v phantomjs >/dev/null;")
    end

    def port_available?(port)
      TCPServer.open(port).close
      true
    rescue Errno::EADDRINUSE
      false
    end

    def port
      @port ||= ENV["TEST_SERVER_PORT"] || 60099
    end

    def start_rails_server
      Demon::RailsAutospec.start(1)
    end

    def stop_rails_server
      Demon::RailsAutospec.stop
    end

    def children_processes(base = Process.pid)
      process_tree = Hash.new { |hash, key| hash[key] = [key] }
      Hash[*`ps -eo pid,ppid`.scan(/\d+/).map(&:to_i)].each do |pid, ppid|
        process_tree[ppid] << process_tree[pid]
      end
      process_tree[base].flatten - [base]
    end

    def kill_process(pid)
      return unless pid
      Process.kill("INT", pid) rescue nil
      while (Process.getpgid(pid) rescue nil)
        sleep 0.001
      end
    end

    def try_to_find_module_name(file)
      return unless File.exists?(file)
      File.open(file, "r").each_line do |line|
        if m = /module\(['"]([^'"]+)/i.match(line)
          return m[1]
        end
      end
    end

  end

end

# frozen_string_literal: true

require "demon/rails_autospec"
require "chrome_installed_checker"

module Autospec

  class QunitRunner < BaseRunner

    WATCHERS = {}
    def self.watch(pattern, &blk)
      WATCHERS[pattern] = blk
    end
    def watchers
      WATCHERS
    end

    # Discourse specific
    watch(%r{^app/assets/javascripts/discourse/(.+)\.js$}) { |m| "test/javascripts/#{m[1]}-test.js" }
    watch(%r{^app/assets/javascripts/admin/(.+)\.js$})     { |m| "test/javascripts/admin/#{m[1]}-test.js" }
    watch(%r{^test/javascripts/.+\.js$})
    watch(%r{^app/assets/javascripts/discourse/tests/.+\.js$})

    RELOADERS = Set.new
    def self.reload(pattern)
      RELOADERS << pattern
    end
    def reloaders
      RELOADERS
    end

    # Discourse specific
    reload(%r{^discourse/tests/javascripts/fixtures/.+_fixtures\.js(\.es6)?$})
    reload(%r{^discourse/tests/javascripts/(helpers|mixins)/.+\.js(\.es6)?$})
    reload("app/assets/javascripts/discoruse/tests/javascripts/test-boot-rails.js")

    watch(%r{^plugins/.*/test/.+\.js(\.es6)?$})

    require "socket"

    def initialize
      ChromeInstalledChecker.run
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
      Demon::RailsAutospec.ensure_running

      abort

      qunit_url = +"http://localhost:#{port}/qunit"

      if specs != "spec"
        module_or_filename, test_id, _name = specs.strip.split(":::")
        module_name = module_or_filename
        if !test_id
          module_name = try_to_find_module_name(module_or_filename)
          qunit_url << "?module=#{module_name}" if module_name
        else
          qunit_url << "?testId=#{test_id}"
        end
      end

      cmd = "node #{Rails.root}/test/run-qunit.js \"#{qunit_url}\" 3000000 ./tmp/qunit_result"

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
      abort
      stop_rails_server
      @running = false
    end

    private

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
      file, _ = file.split(/:\d+$/)
      return unless File.exist?(file)
      File.open(file, "r").each_line do |line|
        if m = /module\(['"]([^'"]+)/i.match(line)
          return m[1]
        end
        if m = /moduleForWidget\(['"]([^"']+)/i.match(line)
          return "widget:#{m[1]}"
        end
        if m = /acceptance\(['"]([^"']+)/i.match(line)
          return "Acceptance: #{m[1]}"
        end
        if m = /moduleFor\(['"]([^'"]+)/i.match(line)
          return m[1]
        end
        if m = /moduleForComponent\(['"]([^"']+)/i.match(line)
          return m[1]
        end
      end

      nil
    end

  end

end

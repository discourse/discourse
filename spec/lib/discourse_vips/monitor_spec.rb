# frozen_string_literal: true

require "net/http"
require "timeout"

RSpec.describe DiscourseVips::Monitor do
  let(:directory) { Dir.mktmpdir("vips-monitor") }
  let(:environment) { "monitor-#{Process.pid}" }
  let(:worker_directory) { Rails.root.join("tmp/discourse-vips-worker", environment).to_s }
  let(:worker_socket_path) { File.join(worker_directory, "socket") }
  let(:port) { TCPServer.open("127.0.0.1", 0) { |listener| listener.local_address.ip_port } }

  def wait_until
    Timeout.timeout(15) do
      loop do
        result = yield
        return result if result
        sleep 0.05
      end
    end
  end

  def worker_version
    UNIXSocket.open(worker_socket_path) do |socket|
      socket.write(MessagePack.pack(command: ["version"], timeout: 5, read: [], write: []))
      socket.close_write
      MessagePack.unpack(socket.read).fetch("value")
    end
  end

  def process_running?(pid)
    stat = File.read("/proc/#{pid}/stat")
    stat[stat.rindex(")") + 2] != "Z"
  rescue Errno::ENOENT
    false
  end

  def monitor_request
    UNIXSocket.open(File.join(worker_directory, "monitor-#{@monitor_pid}.sock")) do |socket|
      socket.write("E")
      socket.gets
    end
  end

  before do
    script = <<~RUBY
      require "pitchfork"
      require "discourse_vips/monitor"

      root, environment, port, directory = ARGV
      DiscourseVips::Monitor.configure(root:, environment:)
      logger = Logger.new(File.join(directory, "pitchfork.log"))
      app = ->(_env) { [200, { "content-type" => "text/plain" }, ["ok"]] }
      server = Pitchfork::HttpServer.new(
        app,
        listeners: ["127.0.0.1:" + port],
        worker_processes: 1,
        logger:,
        after_monitor_ready: ->(_server) { DiscourseVips::Monitor.start(logger:) }
      )
      server.config.before_service_worker_ready do |_server, _service|
        DiscourseVips::Monitor.ensure_running if #{!RSpec.current_example.metadata[:disabled]}
        File.write(File.join(directory, "service.pid"), Process.pid)
      end
      server.config.refork_after([1, false]) if #{!!RSpec.current_example.metadata[:refork]}
      server.config.commit!(server, skip: [:listeners, :pid])
      exit(server.start(false).join)
    RUBY
    @monitor_pid =
      Process.spawn(
        RbConfig.ruby,
        "-I",
        Rails.root.join("lib").to_s,
        "-e",
        script,
        Rails.root.to_s,
        environment,
        port.to_s,
        directory,
        out: File.join(directory, "output.log"),
        err: %i[child out],
      )
    wait_until do
      if Process.waitpid(@monitor_pid, Process::WNOHANG)
        @monitor_pid = nil
        raise File.read(File.join(directory, "output.log"))
      end
      File.exist?(File.join(directory, "service.pid"))
    end
    unless RSpec.current_example.metadata[:disabled]
      @worker_pid = File.read(Rails.root.join("tmp/pids/discourse_vips_0.pid")).to_i
    end
  end

  after do
    begin
      Process.kill("TERM", @monitor_pid)
    rescue StandardError
      nil
    end
    Timeout.timeout(15) { Process.waitpid(@monitor_pid) } if @monitor_pid
    FileUtils.rm_rf(directory)
    FileUtils.rm_rf(worker_directory)
  end

  describe ".ensure_running" do
    it "keeps the same monitor-owned worker serving across a refork", refork: true do
      service_pid_file = File.join(directory, "service.pid")
      old_service_pid = File.read(service_pid_file).to_i
      worker_stat = File.read("/proc/#{@worker_pid}/stat")
      expect(worker_stat[worker_stat.rindex(")") + 2..].split[1].to_i).to eq(@monitor_pid)
      expect(worker_version).to match(/\A\d+\.\d+\.\d+\z/)

      expect(Net::HTTP.get(URI("http://127.0.0.1:#{port}"))).to eq("ok")
      new_service_pid =
        wait_until do
          pid = File.read(service_pid_file).to_i
          pid if pid != old_service_pid
        end

      expect(process_running?(new_service_pid)).to eq(true)
      expect(File.read(Rails.root.join("tmp/pids/discourse_vips_0.pid")).to_i).to eq(@worker_pid)
      expect(worker_version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(Net::HTTP.get(URI("http://127.0.0.1:#{port}"))).to eq("ok")
    end

    it "restarts an exited worker when monitoring requests it" do
      Process.kill("KILL", @worker_pid)
      wait_until { !process_running?(@worker_pid) }

      expect(monitor_request).to eq("OK\n")

      replacement_pid = File.read(Rails.root.join("tmp/pids/discourse_vips_0.pid")).to_i
      expect(replacement_pid).not_to eq(@worker_pid)
      expect(worker_version).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe ".start" do
    it "leaves the image worker unstarted until it is requested", disabled: true do
      expect(File.exist?(worker_socket_path)).to eq(false)
      expect(File.exist?(Rails.root.join("tmp/pids/discourse_vips_0.pid"))).to eq(false)
    end
  end

  describe ".shutdown" do
    it "stops the worker and removes its sockets when the monitor exits" do
      Process.kill("TERM", @monitor_pid)
      Process.waitpid(@monitor_pid)
      @monitor_pid = nil

      wait_until { !process_running?(@worker_pid) }

      expect(File.exist?(worker_socket_path)).to eq(false)
      expect(Dir.glob(File.join(worker_directory, "monitor-*.sock"))).to eq([])
    end
  end
end

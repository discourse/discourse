# frozen_string_literal: true

require "demon/base"

RSpec.describe DiscourseVips::WorkerProcess do
  describe "#initialize" do
    it "stops its worker when the owning process is killed" do
      shared_worker = DiscourseVips::Client.shared_worker?
      Dir.mktmpdir do |directory|
        socket_path = File.join(directory, "worker", "socket")
        DiscourseVips::WorkerProcess.stubs(:shared_socket_path).returns(socket_path)
        reader, writer = IO.pipe
        owner_pid =
          fork do
            reader.close
            worker = described_class.new(socket_path:)
            writer.puts(worker.pid)
            writer.close
            sleep
          end
        writer.close
        worker_pid = Integer(Timeout.timeout(5) { reader.gets })
        DiscourseVips::Client.use_shared_worker
        expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)

        Process.kill("KILL", owner_pid)
        Process.waitpid(owner_pid)
        owner_pid = nil

        wait_for(timeout: 5) { !File.exist?(socket_path) && !Demon::Base.running?(worker_pid) }
      ensure
        reader&.close unless reader&.closed?
        writer&.close unless writer&.closed?
        if owner_pid
          Process.kill("KILL", owner_pid)
          Process.waitpid(owner_pid)
        end
        begin
          Process.kill("KILL", -worker_pid) if worker_pid
        rescue Errno::ESRCH
        end
      end
    ensure
      if shared_worker
        DiscourseVips::Client.use_shared_worker
      else
        DiscourseVips::Client.use_private_worker
      end
    end
  end
end

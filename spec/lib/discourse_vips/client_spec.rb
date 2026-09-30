# frozen_string_literal: true

RSpec.describe DiscourseVips::Client do
  describe ".call" do
    let(:directory) { Dir.mktmpdir }
    let(:socket_path) { File.join(directory, "socket") }
    let(:server_thread) { nil }

    around do |example|
      shared_worker = described_class.instance_variable_get(:@shared_worker)
      example.run
    ensure
      described_class.instance_variable_set(:@shared_worker, shared_worker)
    end

    before do
      DiscourseVips::WorkerProcess.stubs(:shared_socket_path).returns(socket_path)
      described_class.use_shared_worker
    end

    after do
      server_thread&.kill
      server_thread&.join
      FileUtils.remove_entry(directory)
    end

    context "when the shared worker restarts" do
      let(:server_thread) do
        Thread.new do
          sleep 0.2
          server = UNIXServer.new(socket_path)
          connection = server.accept
          MessagePack.unpack(connection.read)
          connection.write(MessagePack.pack({ "status" => "ok", "value" => "8.15.0" }))
        ensure
          connection&.close
          server&.close
        end
      end

      it "waits for the socket to return and receives the response" do
        server_thread

        expect(
          described_class.call(["version"], operation: :vips_version, read: [], write: []),
        ).to eq("8.15.0")
      end
    end

    it "reports a private worker startup failure without retrying" do
      described_class.instance_variable_set(:@shared_worker, false)
      Process.expects(:spawn).once.raises(Errno::ENOENT)

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::WorkerUnavailable)
    end

    it "raises when the shared worker remains unavailable" do
      stub_const(described_class, :SHARED_WORKER_RETRY_SECONDS, 0.2) do
        expect {
          described_class.call(["version"], operation: :vips_version, read: [], write: [])
        }.to raise_error(DiscourseVips::WorkerUnavailable)
      end
    end
  end
end

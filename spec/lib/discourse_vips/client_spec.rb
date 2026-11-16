# frozen_string_literal: true

RSpec.describe DiscourseVips::Client do
  describe ".call" do
    let(:directory) { Dir.mktmpdir }
    let(:socket_path) { File.join(directory, "socket") }
    let(:servers) { [] }
    let(:server_threads) { [] }
    let(:requests) { Queue.new }

    around do |example|
      shared_worker = described_class.shared_worker?
      example.run
    ensure
      shared_worker ? described_class.use_shared_worker : described_class.use_private_worker
    end

    before do
      DiscourseVips::WorkerProcess.stubs(:shared_socket_path).returns(socket_path)
      described_class.use_shared_worker
    end

    after do
      server_threads.each(&:kill)
      server_threads.each(&:join)
      servers.each(&:close)
      FileUtils.remove_entry(directory)
    end

    def serve(response:, delay_seconds: 0)
      server = UNIXServer.new(socket_path)
      servers << server
      server_threads << Thread.new do
        loop do
          connection = server.accept
          begin
            requests << MessagePack.unpack(connection.read)
            sleep delay_seconds if delay_seconds.positive?
            connection.write(response) if response
          ensure
            connection.close
          end
        end
      end
    end

    def restore_socket_after_failure(
      connection_error:,
      outage_seconds: 0,
      response_delay_seconds: 0
    )
      address = Addrinfo.unix(socket_path)
      allow(Addrinfo).to receive(:unix).with(socket_path).and_return(address)
      allow(address).to receive(:connect).and_wrap_original do |connect, **options|
        connect.call(**options)
      rescue connection_error
        sleep outage_seconds if outage_seconds.positive?
        File.unlink(socket_path) if File.exist?(socket_path)
        serve(
          response: MessagePack.pack({ "status" => "ok", "value" => "8.15.0" }),
          delay_seconds: response_delay_seconds,
        )
        raise
      end
    end

    it "recovers when the shared worker socket is missing" do
      restore_socket_after_failure(connection_error: Errno::ENOENT)

      result =
        stub_const(described_class, :WORKER_GRACE_SECONDS, 0) do
          Timeout.timeout(5) do
            described_class.call(
              ["version"],
              operation: :vips_version,
              timeout: 1,
              read: [],
              write: [],
            )
          end
        end

      expect(result).to eq("8.15.0")
      expect(requests.size).to eq(1)
      expect(requests.pop.fetch("timeout")).to eq(1)
    end

    it "recovers when the shared worker socket refuses connections" do
      UNIXServer.new(socket_path).close
      restore_socket_after_failure(connection_error: Errno::ECONNREFUSED)

      result =
        stub_const(described_class, :WORKER_GRACE_SECONDS, 0) do
          Timeout.timeout(5) do
            described_class.call(
              ["version"],
              operation: :vips_version,
              timeout: 1,
              read: [],
              write: [],
            )
          end
        end

      expect(result).to eq("8.15.0")
      expect(requests.size).to eq(1)
      expect(requests.pop.fetch("timeout")).to eq(1)
    end

    it "charges shared connection recovery against the operation timeout" do
      restore_socket_after_failure(
        connection_error: Errno::ENOENT,
        outage_seconds: 0.6,
        response_delay_seconds: 0.6,
      )

      stub_const(described_class, :WORKER_GRACE_SECONDS, 0) do
        Timeout.timeout(5) do
          expect {
            described_class.call(
              ["version"],
              operation: :vips_version,
              timeout: 1,
              read: [],
              write: [],
            )
          }.to raise_error(DiscourseVips::WorkerUnavailable, "libvips worker did not respond")
        end
      end

      expect(requests.size).to eq(1)
    end

    it "bounds the wait when the shared worker remains unavailable" do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      stub_const(described_class, :WORKER_GRACE_SECONDS, 0) do
        Timeout.timeout(5) do
          expect {
            described_class.call(
              ["version"],
              operation: :vips_version,
              timeout: 0.2,
              read: [],
              write: [],
            )
          }.to raise_error(DiscourseVips::WorkerUnavailable)
        end
      end

      elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      expect(elapsed_seconds).to be_between(0.15, 2)
    end

    it "reports a private worker startup failure without retrying" do
      described_class.use_private_worker
      Process.expects(:spawn).once.raises(Errno::ENOENT)

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::WorkerUnavailable)
    end

    it "preserves an empty response without replaying the accepted request" do
      serve(response: nil)

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::WorkerUnavailable)

      expect(requests.size).to eq(1)
    end

    it "preserves an invalid response without replaying the accepted request" do
      serve(response: "\xC1")

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::WorkerUnavailable)

      expect(requests.size).to eq(1)
    end

    it "preserves an operation timeout without replaying the request" do
      serve(response: MessagePack.pack({ "status" => "timeout" }))

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::OperationTimeout)

      expect(requests.size).to eq(1)
    end

    it "preserves an invalid image error without replaying the request" do
      serve(
        response: MessagePack.pack({ "status" => "invalid_image", "message" => "invalid image" }),
      )

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::InvalidImage)

      expect(requests.size).to eq(1)
    end

    it "preserves an operation error without replaying the request" do
      serve(response: MessagePack.pack({ "status" => "error", "message" => "operation failed" }))

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::Error)

      expect(requests.size).to eq(1)
    end
  end
end

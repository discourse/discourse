# frozen_string_literal: true

RSpec.describe DiscourseVips::Client do
  describe ".call" do
    let(:directory) { Dir.mktmpdir }
    let(:socket_path) { File.join(directory, "socket") }
    let(:servers) { [] }
    let(:server_threads) { [] }
    let(:requests) { Queue.new }

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
      server_threads.each(&:kill)
      server_threads.each(&:join)
      servers.each(&:close)
      FileUtils.remove_entry(directory)
    end

    def serve(response:)
      server = UNIXServer.new(socket_path)
      servers << server
      server_threads << Thread.new do
        loop do
          connection = server.accept
          begin
            requests << MessagePack.unpack(connection.read)
            connection.write(response) if response
          ensure
            connection.close
          end
        end
      end
    end

    [Errno::ENOENT, Errno::ECONNREFUSED].each do |connection_error|
      it "recovers when a shared socket initially raises #{connection_error}" do
        UNIXServer.new(socket_path).close if connection_error == Errno::ECONNREFUSED
        address = Addrinfo.unix(socket_path)
        allow(Addrinfo).to receive(:unix).with(socket_path).and_return(address)
        allow(address).to receive(:connect).and_wrap_original do |connect, **options|
          connect.call(**options)
        rescue connection_error
          sleep 1.1
          File.unlink(socket_path) if File.exist?(socket_path)
          serve(response: MessagePack.pack({ "status" => "ok", "value" => "8.15.0" }))
          raise
        end

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
    end

    it "bounds the wait when the shared worker remains unavailable" do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      stub_const(described_class, :SHARED_WORKER_RETRY_SECONDS, 0.2) do
        Timeout.timeout(5) do
          expect {
            described_class.call(["version"], operation: :vips_version, read: [], write: [])
          }.to raise_error(DiscourseVips::WorkerUnavailable)
        end
      end

      elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      expect(elapsed_seconds).to be_between(0.15, 2)
    end

    it "reports a private worker startup failure without retrying" do
      described_class.instance_variable_set(:@shared_worker, false)
      Process.expects(:spawn).once.raises(Errno::ENOENT)

      expect {
        described_class.call(["version"], operation: :vips_version, read: [], write: [])
      }.to raise_error(DiscourseVips::WorkerUnavailable)
    end

    [nil, "\xC1"].each do |response|
      it "preserves a failed response without replaying the accepted request (#{response.inspect})" do
        serve(response:)

        expect {
          described_class.call(["version"], operation: :vips_version, read: [], write: [])
        }.to raise_error(DiscourseVips::WorkerUnavailable)

        expect(requests.size).to eq(1)
      end
    end

    {
      "timeout" => DiscourseVips::OperationTimeout,
      "invalid_image" => DiscourseVips::InvalidImage,
      "error" => DiscourseVips::Error,
    }.each do |status, error_class|
      it "preserves the #{status} operation result without replaying the request" do
        serve(response: MessagePack.pack({ "status" => status, "message" => "operation failed" }))

        expect {
          described_class.call(["version"], operation: :vips_version, read: [], write: [])
        }.to raise_error(error_class)

        expect(requests.size).to eq(1)
      end
    end
  end
end

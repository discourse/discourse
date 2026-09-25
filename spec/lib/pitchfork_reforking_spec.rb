# frozen_string_literal: true

RSpec.describe PitchforkReforking do
  describe PitchforkReforking::PromotionGuard do
    let(:fork_lock) { Monitor.new }
    let(:worker) { Struct.new(:to_log).new("worker=0") }
    let(:defer) { Class.new { include Scheduler::Deferrable }.new }
    let(:server) do
      Class
        .new do
          def logger
            Logger.new(StringIO.new)
          end

          def spawn_mold(_worker)
            yield
          end
        end
        .prepend(PitchforkReforking::PromotionGuard)
        .new
    end

    around do |example|
      pitchfork = Module.new
      stub_const(Object, :Pitchfork, pitchfork) do
        stub_const(pitchfork, :FORK_LOCK, fork_lock) do
          stub_const(Scheduler, :Defer, defer) { example.run }
        end
      end
    ensure
      defer.stop!
    end

    describe "#spawn_mold" do
      it "skips active native work and promotes after it finishes" do
        entered = Queue.new
        release = Queue.new
        native_work =
          Thread.new do
            fork_lock.synchronize do
              entered << true
              release.pop
            end
          end
        expect(entered.pop(timeout: 5)).to eq(true)

        expect(server.spawn_mold(worker) { raise "forked during native work" }).to eq(false)
        release << true
        native_work.join
        child = server.spawn_mold(worker) { fork { exit!(0) } }
        _, status = Process.wait2(child)

        expect(status).to be_success
      ensure
        release << true
        native_work&.join(5)
      end

      it "preserves pending deferred work when promotion is skipped" do
        defer.async = true
        defer.pause
        completed = []
        defer.later { completed << :original }

        expect(server.spawn_mold(worker) { raise "forked with pending work" }).to eq(false)
        defer.do_all_work

        expect(completed).to eq([:original])
        expect(server.spawn_mold(worker) { :promoted }).to eq(:promoted)
      end

      it "releases both barriers after a failed promotion" do
        expect { server.spawn_mold(worker) { raise "fork failed" } }.to raise_error("fork failed")

        operation = Thread.new { server.spawn_mold(worker) { :promoted } }

        expect(operation.join(5)).to eq(operation)
        expect(operation.value).to eq(:promoted)
      ensure
        operation&.kill
        operation&.join
      end

      it "rejects manual promotion with multithreaded V8" do
        global_setting :mini_racer_single_threaded, false

        expect(server.spawn_mold(worker) { raise "forked multithreaded V8" }).to eq(false)
      end
    end
  end

  describe ".parse_schedule" do
    it "supports per-generation limits and a final stop marker" do
      expect(described_class.parse_schedule("100, 500, false")).to eq([100, 500, false])
      expect(described_class.parse_schedule("1000")).to eq([1000])
    end

    it "rejects malformed or out-of-range limits" do
      [
        "",
        "0",
        "-1",
        "1.5",
        "false",
        "1,,2",
        "1,",
        "1,false,2",
        "1,true",
        "2147483648",
      ].each do |value|
        expect { described_class.parse_schedule(value) }.to raise_error(
          ArgumentError,
          /APP_SERVER_REFORK_AFTER/,
        )
      end
    end
  end

  describe ".detach_message_bus_clients" do
    it "detaches child sockets without writing to or shutting down the parent connection" do
      reader, writer = UNIXSocket.pair
      client = MessageBus::Client.new(client_id: "refork-client")
      client.io = writer
      client.headers = {}
      client.use_chunked = true

      child =
        fork do
          reader.close
          described_class.detach_message_bus_clients
          client.close
          exit!(client.io.nil? ? 0 : 1)
        end
      _, status = Process.wait2(child)

      expect(status).to be_success
      expect(reader.read_nonblock(4096, exception: false)).to eq(:wait_readable)
      client.ensure_first_chunk_sent
      expect(reader.read_nonblock(4096)).to include("HTTP/1.1 200 OK")
    ensure
      reader&.close
      writer&.close unless writer&.closed?
    end
  end
end

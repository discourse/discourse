# frozen_string_literal: true

RSpec.describe PitchforkReforking do
  describe ".dispose_v8_contexts" do
    it "disposes contexts and rebuilds the rendering and compiler contexts on demand" do
      rendering = PrettyText.v8
      compiler = AssetProcessor.v8
      temporary = MiniRacer::Context.new
      temporary.eval("1 + 1")

      described_class.dispose_v8_contexts

      [rendering, compiler, temporary].each do |context|
        expect { context.eval("1 + 1") }.to raise_error(MiniRacer::ContextDisposedError)
      end
      expect(PrettyText.cook("**rebuilt**")).to include("<strong>rebuilt</strong>")
      expect(AssetProcessor.v8.eval("1 + 1")).to eq(2)
    end
  end

  describe PitchforkReforking::PromotionGuard do
    let(:fork_lock) { Monitor.new }
    let(:worker) { Struct.new(:to_log).new("worker=0") }
    let(:defer) { Class.new { include Scheduler::Deferrable }.new }
    let(:spawn_timeout) { 5 }
    let(:server) do
      Class
        .new do
          def initialize(spawn_timeout:)
            @spawn_timeout = spawn_timeout
          end

          def logger
            Logger.new(StringIO.new)
          end

          def spawn_mold(_worker, &block)
            fork_sibling("spawn_mold", &block)
          end

          private

          def fork_sibling(_role)
            yield
          end
        end
        .prepend(PitchforkReforking::PromotionGuard)
        .new(spawn_timeout: spawn_timeout)
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
      it "waits for native work before promoting" do
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
        promotion = Thread.new { server.spawn_mold(worker) { :promoted } }
        wait_for { promotion.status == "sleep" }

        release << true

        expect(promotion.join(5)).to eq(promotion)
        expect(promotion.value).to eq(:promoted)
      ensure
        release << true
        native_work&.join(5)
        promotion&.join(5)
      end

      it "drains existing deferred work before promoting" do
        defer.async = true
        started = Queue.new
        release = Queue.new
        completed = Queue.new
        defer.later do
          started << true
          release.pop
          completed << :original
        end
        expect(started.pop(timeout: 5)).to eq(true)
        promotion = Thread.new { server.spawn_mold(worker) { :promoted } }
        wait_for { promotion.status == "sleep" }

        release << true

        expect(promotion.join(5)).to eq(promotion)
        expect(promotion.value).to eq(:promoted)
        expect(completed.pop(timeout: 5)).to eq(:original)
      ensure
        release << true
        promotion&.join(5)
      end

      it "abandons promotion after the drain timeout without losing deferred work" do
        defer.async = true
        started = Queue.new
        release = Queue.new
        completed = Queue.new
        defer.later do
          started << true
          release.pop
          completed << :finished
        end
        expect(started.pop(timeout: 5)).to eq(true)
        short_timeout_server = server.class.new(spawn_timeout: 0.05)

        expect(short_timeout_server.spawn_mold(worker) { raise "forked before drain" }).to eq(false)
        release << true

        expect(completed.pop(timeout: 5)).to eq(:finished)
        expect(server.spawn_mold(worker) { :promoted }).to eq(:promoted)
      ensure
        release << true
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

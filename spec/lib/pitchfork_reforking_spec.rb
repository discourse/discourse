# frozen_string_literal: true

RSpec.describe PitchforkReforking do
  describe ".prevent_fork" do
    before { require "pitchfork" }

    it "holds off forks while a background thread runs the block" do
      entered = Queue.new
      release = Queue.new
      background =
        Thread.new do
          described_class.prevent_fork do
            entered << true
            release.pop
          end
        end
      expect(entered.pop(timeout: 5)).to eq(true)
      forking = Thread.new { Pitchfork.prevent_fork { :forked } }

      expect(forking.join(0.1)).to eq(nil)
      release << true
      expect(forking.value).to eq(:forked)
    ensure
      release << true
      background&.join(5)
    end

    it "does not lock on the main thread, which is the thread that forks" do
      blocker =
        Thread.new do
          Pitchfork.prevent_fork do
            Thread.current[:locked] = true
            sleep
          end
        end
      wait_for { blocker[:locked] }

      expect(described_class.prevent_fork { :ran }).to eq(:ran)
    ensure
      blocker&.kill
      blocker&.join(5)
    end
  end

  it "keeps V8 contexts usable in a process forked after they were warmed" do
    expect(PrettyText.cook("**parent**")).to include("<strong>parent</strong>")
    expect(AssetProcessor.v8.eval("1 + 1")).to eq(2)

    reader, writer = IO.pipe
    child =
      fork do
        reader.close
        writer.write(PrettyText.cook("**child**"))
        writer.write(AssetProcessor.v8.eval("2 + 2").to_s)
        exit!(0)
      end
    writer.close
    output = reader.read
    _, status = Process.wait2(child)

    expect(status).to be_success
    expect(output).to include("<strong>child</strong>")
    expect(output).to end_with("4")
  ensure
    reader&.close
  end

  describe ".wait_for_idle_thread_pools" do
    let(:pool) { Scheduler::ThreadPool.new(min_threads: 0, max_threads: 1, idle_time: 1) }

    after do
      pool.shutdown
      pool.wait_for_termination(timeout: 1)
    end

    it "waits for running tasks and gives up after the timeout" do
      started = Queue.new
      release = Queue.new
      pool.post do
        started << true
        release.pop
      end
      expect(started.pop(timeout: 5)).to eq(true)

      expect(described_class.wait_for_idle_thread_pools(timeout: 0.05)).to eq(false)
      release << true
      expect(described_class.wait_for_idle_thread_pools(timeout: 5)).to eq(true)
    ensure
      release << true
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

# frozen_string_literal: true

describe FinalDestination::SSRFSafeSocket do
  before { WebMock.disable! }
  after { WebMock.enable! }

  def with_listening_port
    server = TCPServer.new("127.0.0.1", 0)
    thread =
      Thread.new do
        loop { server.accept.close }
      rescue IOError, Errno::EBADF
        nil
      end
    yield server.addr[1]
  ensure
    server&.close
    thread&.kill
  end

  def elapsed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  describe ".open" do
    it "connects to a vetted address and returns a blocking socket" do
      with_listening_port do |port|
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

        socket = described_class.open("test.invalid", port)

        expect(socket.remote_address.ip_address).to eq("127.0.0.1")
        expect(socket.nonblock?).to eq(false)
        socket.close
      end
    end

    it "races past a blackholed address to a reachable one" do
      with_listening_port do |port|
        # 192.0.2.1 (TEST-NET-1) silently drops SYNs; the race must step past it.
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(
          %w[192.0.2.1 127.0.0.1],
        )

        socket = nil
        duration = elapsed { socket = described_class.open("test.invalid", port) }

        expect(socket.remote_address.ip_address).to eq("127.0.0.1")
        expect(duration).to be < 10
        socket.close
      end
    end

    it "raises a SystemCallError when every address refuses the connection" do
      closed = TCPServer.new("127.0.0.1", 0)
      port = closed.addr[1]
      closed.close
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

      expect { described_class.open("test.invalid", port) }.to raise_error(SystemCallError)
    end

    it "propagates SSRF errors from the detector" do
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).raises(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )

      expect { described_class.open("blocked.invalid", 80) }.to raise_error(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )
    end
  end

  describe "address capping" do
    it "attempts at most MAX_ADDRESSES_PER_FAMILY addresses per family" do
      cap = described_class::MAX_ADDRESSES_PER_FAMILY
      ipv4 = Array.new(100) { |n| "93.184.216.#{n}" }
      ipv6 = Array.new(100) { |n| "2606:2800:220:1:248:1893:25c8:#{n.to_s(16)}" }
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(ipv6 + ipv4)

      addresses = described_class.new("example.com", 443).send(:vetted_addresses)

      expect(addresses.count { |ip| ip.include?(":") }).to eq(cap)
      expect(addresses.count { |ip| !ip.include?(":") }).to eq(cap)
    end
  end
end

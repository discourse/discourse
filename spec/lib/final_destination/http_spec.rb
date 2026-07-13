# frozen_string_literal: true

require "webrick"

describe FinalDestination::HTTP do
  before do
    # We need to test low-level stuff, switch off WebMock for FinalDestination::HTTP
    WebMock.enable!(except: [:final_destination])
    FinalDestination::SSRFDetector.allow_ip_lookups_in_test!
  end

  after do
    WebMock.enable!
    FinalDestination::SSRFDetector.disallow_ip_lookups_in_test!
  end

  # Runs `blk` and returns the addresses FinalDestination handed to the socket
  # layer, without letting it actually connect. The vetted, SSRF-filtered
  # addresses ride inside a Connector token; decode it and abort.
  def addresses_offered_to_socket
    offered = nil
    aborted = Class.new(StandardError)
    Socket
      .stubs(:tcp)
      .with do |host, *|
        next false unless FinalDestination::Connector.token?(host)
        offered = FinalDestination::Connector.addresses(host)
        true
      end
      .raises(aborted)
    begin
      yield
    rescue aborted
    end
    offered
  end

  # A minimal HTTP server on `bind`:<ephemeral> that answers every request with "hi".
  def with_http_server(bind = "127.0.0.1")
    server =
      WEBrick::HTTPServer.new(
        BindAddress: bind,
        Port: 0,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: [],
      )
    server.mount_proc("/") { |_req, res| res.body = "hi" }
    thread = Thread.new { server.start }
    yield server.config[:Port]
  ensure
    server&.shutdown
    thread&.join
  end

  def elapsed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  describe "SSRF filtering" do
    it "offers only the non-private addresses to the socket layer" do
      stub_ip_lookup("example.com", %w[0.0.0.0 93.184.216.34])

      offered =
        addresses_offered_to_socket { FinalDestination::HTTP.get(URI("https://example.com")) }

      expect(offered).to eq(%w[93.184.216.34])
    end

    it "offers otherwise-blocked addresses when the host is allowlisted" do
      SiteSetting.allowed_internal_hosts = "internal.example.com"
      stub_ip_lookup("internal.example.com", %w[10.0.0.5])

      offered =
        addresses_offered_to_socket do
          FinalDestination::HTTP.get(URI("https://internal.example.com"))
        end

      expect(offered).to eq(%w[10.0.0.5])
    end

    it "caps how many addresses are offered to the socket, per family" do
      # a hostname's DNS response is attacker-controlled; a huge one must not turn
      # into an unbounded fan-out of concurrent connection attempts
      cap = FinalDestination::HTTP::MAX_ADDRESSES_PER_FAMILY
      ipv4 = Array.new(100) { |n| "93.184.216.#{n}" }
      ipv6 = Array.new(100) { |n| "2606:2800:220:1:248:1893:25c8:#{n.to_s(16)}" }
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(ipv6 + ipv4)

      offered =
        addresses_offered_to_socket { FinalDestination::HTTP.get(URI("https://example.com")) }

      expect(offered.count { |ip| ip.include?(":") }).to eq(cap)
      expect(offered.count { |ip| !ip.include?(":") }).to eq(cap)
    end

    it "raises DisallowedIpError when every address is private" do
      stub_ip_lookup("example.com", %w[0.0.0.0 127.0.0.1])

      expect { FinalDestination::HTTP.get(URI("https://example.com")) }.to raise_error(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )
    end

    it "raises DisallowedIpError when every address is blocked by site setting" do
      SiteSetting.blocked_ip_blocks = "98.0.0.0/8|9001:82f3::/32"
      stub_ip_lookup("ip4.example.com", %w[98.23.19.111])
      stub_ip_lookup("ip6.example.com", %w[9001:82f3:8873::3])

      expect { FinalDestination::HTTP.get(URI("https://ip4.example.com")) }.to raise_error(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )
      expect { FinalDestination::HTTP.get(URI("https://ip6.example.com")) }.to raise_error(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )
    end

    it "handles short IPs" do
      stub_ip_lookup("0", %w[0.0.0.0])

      expect { FinalDestination::HTTP.get(URI("https://0/path")) }.to raise_error(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )
    end

    it "raises SocketError on nxdomain" do
      FinalDestination::SSRFDetector
        .stubs(:lookup_ips)
        .with { |addr| addr == "example.com" }
        .raises(SocketError)

      expect { FinalDestination::HTTP.get(URI("https://example.com")) }.to raise_error(SocketError)
    end
  end

  describe "connecting" do
    it "fetches over a real connection" do
      with_http_server do |port|
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

        body =
          FinalDestination::HTTP.start("test.invalid", port, open_timeout: 5) do |http|
            http.get("/").body
          end

        expect(body).to eq("hi")
      end
    end

    it "connects to a reachable address even when a blackholed one is offered first" do
      with_http_server do |port|
        # 192.0.2.1 (RFC 5737 TEST-NET-1) silently drops SYNs. Happy Eyeballs must
        # step past it to the reachable loopback address; the previous design pinned
        # the first address and would burn the whole open_timeout here.
        FinalDestination::SSRFDetector
          .stubs(:lookup_and_filter_ips)
          .returns(%w[192.0.2.1 127.0.0.1])

        body = nil
        duration =
          elapsed do
            FinalDestination::HTTP.start("test.invalid", port, open_timeout: 30) do |http|
              body = http.get("/").body
            end
          end

        expect(body).to eq("hi")
        expect(duration).to be < 10 # steps past the blackhole in ~250ms, nowhere near 30s
      end
    end

    it "raises when the offered address refuses the connection" do
      # nothing is listening here: bind an ephemeral port then release it
      closed = TCPServer.new("127.0.0.1", 0)
      closed_port = closed.addr[1]
      closed.close
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

      expect do
        FinalDestination::HTTP.start("test.invalid", closed_port, open_timeout: 5) do |http|
          http.get("/")
        end
      end.to raise_error(SystemCallError)
    end

    it "forwards net-http's open_timeout to the socket as a connect deadline" do
      # Some Ruby/net-http versions call TCPSocket.open(..., open_timeout:) with no
      # Timeout.timeout wrapper, so we must pass that deadline on to Socket.tcp;
      # dropping it would let a blackholed address hang on the OS TCP timeout.
      captured = nil
      aborted = Class.new(StandardError)
      Socket
        .stubs(:tcp)
        .with do |host, *_rest, **kwargs|
          next false unless FinalDestination::Connector.token?(host)
          captured = kwargs[:connect_timeout]
          true
        end
        .raises(aborted)

      token = FinalDestination::Connector.encode("test.invalid", %w[203.0.113.1])

      expect { TCPSocket.open(token, 443, nil, nil, open_timeout: 7) }.to raise_error(aborted)
      expect(captured).to eq(7)
    end
  end

  describe "the socket patch" do
    it "leaves ordinary (non-token) TCPSocket.open calls untouched" do
      # the patch is installed globally; every non-FinalDestination socket in the
      # process must still open normally, with no injected keyword arguments
      with_http_server do |port|
        socket = TCPSocket.open("127.0.0.1", port)
        expect(socket).to be_a(TCPSocket)
        socket.close
      end
    end
  end

  describe "via a proxy" do
    # a fake CONNECT proxy that records the line the client tunnels with
    def with_capturing_proxy
      server = TCPServer.new("127.0.0.1", 0)
      connect_line = Queue.new
      acceptor =
        Thread.new do
          conn = server.accept
          connect_line << conn.gets
          conn.write("HTTP/1.1 200 Connection established\r\n\r\n")
          conn.close
        rescue IOError
        end
      yield server.addr[1], connect_line
    ensure
      server&.close
      acceptor&.kill
    end

    it "has the proxy connect to a vetted IP, never the token or hostname" do
      with_capturing_proxy do |proxy_port, connect_line|
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[93.184.216.34])

        http = FinalDestination::HTTP.new("example.com", 443, "127.0.0.1", proxy_port)
        http.use_ssl = true
        http.open_timeout = 2
        begin
          http.start { |h| h.get("/") }
        rescue StandardError
          # the fake proxy never completes TLS; we only care about the CONNECT line
        end

        expect(connect_line.pop(timeout: 2)).to start_with("CONNECT 93.184.216.34:443")
      end
    end
  end

  describe "argument validation" do
    it "rejects a nil address" do
      expect { FinalDestination::HTTP.start(nil) {} }.to raise_error(ArgumentError)
    end

    it "rejects an empty address" do
      expect { FinalDestination::HTTP.start("") {} }.to raise_error(ArgumentError)
    end
  end
end

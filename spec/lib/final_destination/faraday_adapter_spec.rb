# frozen_string_literal: true

require "webrick"

describe FinalDestination::FaradayAdapter do
  before { WebMock.disable! }
  after { WebMock.enable! }

  def faraday
    Faraday.new { |f| f.adapter described_class }
  end

  def with_http_server
    server =
      WEBrick::HTTPServer.new(
        BindAddress: "127.0.0.1",
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

  describe "connecting" do
    it "fetches over a real connection through the SSRF-safe socket" do
      with_http_server do |port|
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

        response = faraday.get("http://test.invalid:#{port}/")

        expect(response.status).to eq(200)
        expect(response.body).to eq("hi")
      end
    end

    it "steps past a blackholed address to a reachable one (Happy Eyeballs)" do
      with_http_server do |port|
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(
          %w[192.0.2.1 127.0.0.1],
        )

        body = nil
        duration = elapsed { body = faraday.get("http://test.invalid:#{port}/").body }

        expect(body).to eq("hi")
        expect(duration).to be < 10
      end
    end

    it "raises Faraday::ConnectionFailed when the connection is refused" do
      closed = TCPServer.new("127.0.0.1", 0)
      port = closed.addr[1]
      closed.close
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

      expect { faraday.get("http://test.invalid:#{port}/") }.to raise_error(
        Faraday::ConnectionFailed,
      )
    end
  end

  describe "SSRF filtering" do
    it "surfaces an SSRF failure when the destination has no allowed IPs" do
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).raises(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )

      # DisallowedIpError < SSRFError < SocketError, so it surfaces as ConnectionFailed
      # with the SSRF error recoverable through the cause chain.
      expect { faraday.get("http://blocked.invalid/") }.to raise_error(
        Faraday::ConnectionFailed,
      ) do |error|
        expect(error.wrapped_exception.cause).to be_a(
          FinalDestination::SSRFDetector::DisallowedIpError,
        )
      end
    end
  end

  describe "via a proxy" do
    def with_capturing_proxy
      server = TCPServer.new("127.0.0.1", 0)
      request_line = Queue.new
      acceptor =
        Thread.new do
          conn = server.accept
          request_line << conn.gets
          conn.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nhi")
          conn.close
        rescue IOError
          nil
        end
      yield server.addr[1], request_line
    ensure
      server&.close
      acceptor&.kill
    end

    it "drops SSRF protection and connects to the proxy directly" do
      with_capturing_proxy do |proxy_port, request_line|
        FinalDestination::SSRFDetector.expects(:lookup_and_filter_ips).never

        conn =
          Faraday.new(proxy: "http://127.0.0.1:#{proxy_port}") { |f| f.adapter described_class }
        conn.get("http://example.com/foo")

        expect(request_line.pop(timeout: 2)).to include("example.com")
      end
    end
  end
end

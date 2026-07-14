# frozen_string_literal: true

require "webrick"

describe FinalDestination::HTTPRb do
  before { WebMock.disable! }
  after { WebMock.enable! }

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

  it "fetches over a real connection through the SSRF-safe socket" do
    with_http_server do |port|
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

      response = described_class.get("http://test.invalid:#{port}/")

      expect(response.status).to eq(200)
      expect(response.to_s).to eq("hi")
    end
  end

  it "keeps the SSRF-safe socket through the chainable DSL" do
    with_http_server do |port|
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[127.0.0.1])

      response =
        described_class.timeout(5).headers("X-Test" => "1").get("http://test.invalid:#{port}/")

      expect(response.status).to eq(200)
    end
  end

  it "races past a blackholed address to a reachable one (Happy Eyeballs)" do
    with_http_server do |port|
      FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(%w[192.0.2.1 127.0.0.1])

      body = nil
      duration = elapsed { body = described_class.get("http://test.invalid:#{port}/").to_s }

      expect(body).to eq("hi")
      expect(duration).to be < 10
    end
  end

  it "surfaces SSRF failures as a connection error carrying the original cause" do
    FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).raises(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )

    expect { described_class.get("http://blocked.invalid/") }.to raise_error(
      HTTP::ConnectionError,
    ) { |error| expect(error.cause).to be_a(FinalDestination::SSRFDetector::DisallowedIpError) }
  end
end

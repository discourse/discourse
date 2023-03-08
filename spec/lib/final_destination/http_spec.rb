# frozen_string_literal: true

require "rails_helper"

describe FinalDestination::HTTP do
  before do
    # We need to test low-level stuff, switch off WebMock for FinalDestination::HTTP
    WebMock.enable!(except: [:final_destination])
    Socket.stubs(:tcp).never
    Addrinfo.stubs(:getaddrinfo).never

    FinalDestination::SSRFDetector.allow_ip_lookups_in_test!
  end

  after do
    WebMock.enable!
    FinalDestination::SSRFDetector.disallow_ip_lookups_in_test!
  end

  def expect_tcp_and_abort(stub_addr, &blk)
    success = Class.new(StandardError)
    Socket.stubs(:tcp).with { |addr| stub_addr == addr }.once.raises(success)
    begin
      yield
    rescue success
    end
  end

  def stub_ip_lookup(stub_addr, ips)
    Addrinfo
      .stubs(:getaddrinfo)
      .with { |addr, _| addr == stub_addr }
      .returns(
        ips.map { |ip| Addrinfo.new([IPAddr.new(ip).ipv6? ? "AF_INET6" : "AF_INET", 80, nil, ip]) },
      )
  end

  def stub_tcp_to_raise(stub_addr, exception)
    Socket.stubs(:tcp).with { |addr| addr == stub_addr }.once.raises(exception)
  end

  it "works through each IP address until success" do
    stub_ip_lookup("example.com", %w[1.1.1.1 2.2.2.2 3.3.3.3])
    stub_tcp_to_raise("1.1.1.1", Errno::ETIMEDOUT)
    stub_tcp_to_raise("2.2.2.2", Errno::EPIPE)
    expect_tcp_and_abort("3.3.3.3") { FinalDestination::HTTP.get(URI("https://example.com")) }
  end

  it "handles nxdomain with SocketError" do
    FinalDestination::SSRFDetector
      .stubs(:lookup_ips)
      .with { |addr| addr == "example.com" }
      .raises(SocketError)
    expect { FinalDestination::HTTP.get(URI("https://example.com")) }.to raise_error(SocketError)
  end

  it "raises the normal error when all IPs fail" do
    stub_ip_lookup("example.com", %w[1.1.1.1 2.2.2.2])
    stub_tcp_to_raise("1.1.1.1", Errno::ETIMEDOUT)
    stub_tcp_to_raise("2.2.2.2", Errno::EPIPE)
    expect { FinalDestination::HTTP.get(URI("https://example.com")) }.to raise_error(Errno::EPIPE)
  end

  it "ignores private IPs" do
    stub_ip_lookup("example.com", %w[0.0.0.0 2.2.2.2])
    expect_tcp_and_abort("2.2.2.2") { FinalDestination::HTTP.get(URI("https://example.com")) }
  end

  it "raises DisallowedIpError if all IPs are private" do
    stub_ip_lookup("example.com", %w[0.0.0.0 127.0.0.1])
    expect { FinalDestination::HTTP.get(URI("https://example.com")) }.to raise_error(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )
    expect(FinalDestination::SSRFDetector::DisallowedIpError.new).to be_a(SocketError)
  end

  it "handles short IPs" do
    stub_ip_lookup("0", %w[0.0.0.0])
    expect { FinalDestination::HTTP.get(URI("https://0/path")) }.to raise_error(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )
    expect(FinalDestination::SSRFDetector::DisallowedIpError.new).to be_a(SocketError)
  end

  it "raises DisallowedIpError if all IPs are blocked" do
    SiteSetting.blocked_ip_blocks = "98.0.0.0/8|78.13.47.0/24|9001:82f3::/32"
    stub_ip_lookup("ip6.example.com", %w[9001:82f3:8873::3])
    stub_ip_lookup("ip4.example.com", %w[98.23.19.111])
    expect { FinalDestination::HTTP.get(URI("https://ip4.example.com")) }.to raise_error(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )
    expect { FinalDestination::HTTP.get(URI("https://ip6.example.com")) }.to raise_error(
      FinalDestination::SSRFDetector::DisallowedIpError,
    )
  end

  it "allows specified hosts to bypass IP checks" do
    SiteSetting.blocked_ip_blocks = "98.0.0.0/8|78.13.47.0/24|9001:82f3::/32"
    SiteSetting.allowed_internal_hosts = "internal.example.com|blocked-ip.example.com"
    stub_ip_lookup("internal.example.com", %w[0.0.0.0 127.0.0.1])
    stub_ip_lookup("blocked-ip.example.com", %w[98.23.19.111])
    expect_tcp_and_abort("0.0.0.0") do
      FinalDestination::HTTP.get(URI("https://internal.example.com"))
    end
    expect_tcp_and_abort("98.23.19.111") do
      FinalDestination::HTTP.get(URI("https://blocked-ip.example.com"))
    end
  end

  it "stops iterating over DNS records once timeout reached" do
    stub_ip_lookup("example.com", %w[1.1.1.1 2.2.2.2 3.3.3.3 4.4.4.4])
    Socket.stubs(:tcp).with { |addr| addr == "1.1.1.1" }.raises(Errno::ECONNREFUSED)
    Socket.stubs(:tcp).with { |addr| addr == "2.2.2.2" }.raises(Errno::ECONNREFUSED)
    Socket
      .stubs(:tcp)
      .with { |*args, **kwargs| kwargs[:open_timeout] == 0 }
      .raises(Errno::ETIMEDOUT)
    FinalDestination::HTTP.any_instance.stubs(:current_time).returns(0, 1, 5)
    expect do
      FinalDestination::HTTP.start("example.com", 80, open_timeout: 5) {}
    end.to raise_error(Net::OpenTimeout)
  end
end

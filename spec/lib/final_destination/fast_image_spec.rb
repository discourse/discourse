# frozen_string_literal: true

describe FinalDestination::FastImage do
  before do
    # We need to test low-level stuff, switch off WebMock for FastImage
    WebMock.enable!(except: [:net_http])
    Socket.stubs(:tcp).never
    TCPSocket.stubs(:open).never
    Addrinfo.stubs(:getaddrinfo).never
  end

  after { WebMock.enable! }

  def expect_tcp_and_abort(stub_addr, &blk)
    success = Class.new(StandardError)
    TCPSocket.stubs(:open).with { |addr| stub_addr == addr }.once.raises(success)
    begin
      yield
    rescue success
    end
  end

  def stub_ip_lookup(stub_addr, ips)
    FinalDestination::SSRFDetector.stubs(:lookup_ips).with { |addr| stub_addr == addr }.returns(ips)
  end

  def stub_tcp_to_raise(stub_addr, exception)
    TCPSocket.stubs(:open).with { |addr| addr == stub_addr }.once.raises(exception)
  end

  it "uses the first resolved IP" do
    stub_ip_lookup("example.com", %w[1.1.1.1 2.2.2.2 3.3.3.3])
    expect_tcp_and_abort("1.1.1.1") do
      FinalDestination::FastImage.size(URI("https://example.com/img.jpg"))
    end
  end

  it "ignores private IPs" do
    stub_ip_lookup("example.com", %w[0.0.0.0 2.2.2.2])
    expect_tcp_and_abort("2.2.2.2") do
      FinalDestination::FastImage.size(URI("https://example.com/img.jpg"))
    end
  end

  it "returns a null object when all IPs are private" do
    stub_ip_lookup("example.com", %w[0.0.0.0 127.0.0.1])
    expect(FinalDestination::FastImage.size(URI("https://example.com/img.jpg"))).to eq(nil)
  end

  it "returns a null object if all IPs are blocked" do
    SiteSetting.blocked_ip_blocks = "98.0.0.0/8|78.13.47.0/24|9001:82f3::/32"
    stub_ip_lookup("ip6.example.com", %w[9001:82f3:8873::3])
    stub_ip_lookup("ip4.example.com", %w[98.23.19.111])
    expect(FinalDestination::FastImage.size(URI("https://ip4.example.com/img.jpg"))).to eq(nil)
    expect(FinalDestination::FastImage.size(URI("https://ip6.example.com/img.jpg"))).to eq(nil)
  end

  it "allows specified hosts to bypass IP checks" do
    SiteSetting.blocked_ip_blocks = "98.0.0.0/8|78.13.47.0/24|9001:82f3::/32"
    SiteSetting.allowed_internal_hosts = "internal.example.com|blocked-ip.example.com"
    stub_ip_lookup("internal.example.com", %w[0.0.0.0 127.0.0.1])
    stub_ip_lookup("blocked-ip.example.com", %w[98.23.19.111])
    expect_tcp_and_abort("0.0.0.0") do
      FinalDestination::FastImage.size(URI("https://internal.example.com/img.jpg"))
    end
    expect_tcp_and_abort("98.23.19.111") do
      FinalDestination::FastImage.size(URI("https://blocked-ip.example.com/img.jpg"))
    end
  end
end

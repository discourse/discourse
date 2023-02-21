# frozen_string_literal: true

describe FinalDestination::Resolver do
  let(:mock_response) { [Addrinfo.ip("1.1.1.1"), Addrinfo.ip("2.2.2.2")] }

  before do
    # No DNS lookups in tests
    Addrinfo.stubs(:getaddrinfo).never
  end

  def alive_thread_count
    Thread.list.filter(&:alive?).count
  end

  it "handles timeouts correctly" do
    Addrinfo.stubs(:getaddrinfo).with { |addr| sleep if addr == "sleep.example.com" } # timeout
    Addrinfo.stubs(:getaddrinfo).with { |addr| addr == "example.com" }.returns(mock_response)

    expect {
      result = FinalDestination::Resolver.lookup("sleep.example.com", timeout: 0.001)
    }.to raise_error(Timeout::Error)

    start_thread_count = alive_thread_count

    expect {
      result = FinalDestination::Resolver.lookup("sleep.example.com", timeout: 0.001)
    }.to raise_error(Timeout::Error)

    expect(alive_thread_count).to eq(start_thread_count)

    expect(FinalDestination::Resolver.lookup("example.com")).to eq(%w[1.1.1.1 2.2.2.2])

    # Thread available for reuse after successful lookup
    expect(alive_thread_count).to eq(start_thread_count + 1)
  end

  it "reads default query timeout from configuration" do
    GlobalSetting.stubs(:dns_query_timeout_secs).returns(123)
    expect(FinalDestination::Resolver.send(:default_dns_query_timeout)).to eq(123)
  end

  it "can lookup correctly" do
    Addrinfo.stubs(:getaddrinfo).with { |addr| addr == "example.com" }.returns(mock_response)

    expect(FinalDestination::Resolver.lookup("example.com")).to eq(%w[1.1.1.1 2.2.2.2])
  end
end

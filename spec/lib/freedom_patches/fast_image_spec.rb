# frozen_string_literal: true

RSpec.describe FastImage do
  before do
    FinalDestination::SSRFDetector.allow_ip_lookups_in_test!
    WebMock.enable!(except: [:final_destination])
  end

  after do
    WebMock.enable!
    FinalDestination::SSRFDetector.disallow_ip_lookups_in_test!
  end

  it "should filter endpoint hostname through our SSRF detector and return null object" do
    stub_ip_lookup("example.com", %W[0.0.0.0])

    expect(described_class.type("http://example.com")).to eq(nil)
  end

  it "should send the right request if endpoint hostname resolves to a public ip address" do
    stub_ip_lookup("example.com", %W[52.125.123.12])

    success = Class.new(StandardError)
    TCPSocket.stubs(:open).with { |addr| "52.125.123.12" == addr }.once.raises(success)

    expect { described_class.type("http://example.com") }.to raise_error(success)
  end
end

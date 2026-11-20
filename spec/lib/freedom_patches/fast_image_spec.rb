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

  it "filters the endpoint hostname through the SSRF detector and returns a null object" do
    stub_ip_lookup("example.com", %W[0.0.0.0])

    expect(described_class.type("http://example.com")).to eq(nil)
  end

  it "sends the request when the endpoint resolves to a public IP address" do
    stub_ip_lookup("example.com", %W[52.125.123.12])

    success = Class.new(StandardError)
    TCPSocket
      .stubs(:open)
      .with do |addr|
        FinalDestination::Connector.token?(addr) &&
          FinalDestination::Connector.addresses(addr) == %w[52.125.123.12]
      end
      .once
      .raises(success)

    expect { described_class.type("http://example.com") }.to raise_error(success)
  end
end

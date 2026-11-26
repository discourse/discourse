# frozen_string_literal: true

RSpec.describe FinalDestination::FaradayAdapter do
  before { WebMock.enable!(except: [:final_destination]) }
  after { WebMock.enable! }

  def configure(ssl)
    FinalDestination::HTTP
      .new("example.com", 443)
      .tap { |http| described_class.new.send(:configure_ssl, http, Faraday::SSLOptions.from(ssl)) }
  end

  it "verifies certificates by default" do
    expect(configure({}).verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
  end

  it "allows a connection to opt out of certificate verification" do
    expect(configure(verify: false).verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
  end

  it "allows a connection to opt out of hostname verification" do
    expect(configure(verify_hostname: false).verify_hostname).to eq(false)
  end
end

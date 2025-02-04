# frozen_string_literal: true

RSpec.describe Onebox::Engine::CloudAppOnebox do
  before do
    stub_request(:get, "https://cl.ly/0m2a2u2k440O").to_return(
      status: 200,
      body: onebox_response("cloudapp-gif"),
    )
    stub_request(:get, "https://cl.ly/0T0c2J3S373X").to_return(
      status: 200,
      body: onebox_response("cloudapp-mp4"),
    )
    stub_request(:get, "https://cl.ly/2C0E1V451J0C").to_return(
      status: 200,
      body: onebox_response("cloudapp-jpg"),
    )
    stub_request(:get, "https://cl.ly/1x1f2g253l03").to_return(
      status: 200,
      body: onebox_response("cloudapp-others"),
    )
  end

  it "supports gif" do
    expect(Onebox.preview("https://cl.ly/0m2a2u2k440O").to_s).to match(/<img/)
  end

  it "supports mp4" do
    expect(Onebox.preview("https://cl.ly/0T0c2J3S373X").to_s).to match(/<video/)
  end

  it "supports jpg" do
    expect(Onebox.preview("https://cl.ly/2C0E1V451J0C").to_s).to match(/<img/)
  end

  it "links to other formats" do
    expect(Onebox.preview("https://cl.ly/1x1f2g253l03").to_s).to match(/<a/)
  end

  describe ".===" do
    it "matches valid cl.ly URL" do
      valid_url = URI("https://cl.ly/path/to/resource")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://cl.ly.malicious.com/path")
      expect(described_class === malicious_url).to eq(false)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Onebox::Engine::ImgurOnebox do
  let(:link) { "https://imgur.com/gallery/Sdc0Klc" }
  let(:imgur) { described_class.new(link) }
  let(:html) { imgur.to_html }

  before { stub_request(:get, link).to_return(status: 200, body: onebox_response("imgur")) }

  it "excludes html tags in title" do
    imgur.stubs(:is_album?).returns(true)
    expect(html).to include("<span class='album-title'>[Album] Did you miss me?</span>")
  end

  describe ".===" do
    it "matches valid Imgur URL" do
      valid_url = URI("https://imgur.com/gallery/abcd1234")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Imgur URL with www" do
      valid_url_with_www = URI("https://www.imgur.com/gallery/abcd1234")
      expect(described_class === valid_url_with_www).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://imgur.com.malicious.com/gallery/abcd1234")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.imgur.com/gallery/abcd1234")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/gallery/abcd1234")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end

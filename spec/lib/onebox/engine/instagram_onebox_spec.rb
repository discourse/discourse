# frozen_string_literal: true

RSpec.describe Onebox::Engine::InstagramOnebox do
  let(:access_token) { "abc123" }
  let(:link) { "https://www.instagram.com/p/CARbvuYDm3Q" }
  let(:onebox_options) do
    { allowed_iframe_regexes: Onebox::Engine.origins_to_regexes(["https://www.instagram.com"]) }
  end

  it "oneboxes links that include the username" do
    link_with_profile = "https://www.instagram.com/bennyblood24/p/CARbvuYDm3Q/"
    onebox_klass = Onebox::Matcher.new(link_with_profile, onebox_options).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  it "oneboxes photo links" do
    photo_link = "https://www.instagram.com/p/CARbvuYDm3Q/"
    onebox_klass = Onebox::Matcher.new(photo_link, onebox_options).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  it "oneboxes tv links" do
    tv_link = "https://www.instagram.com/tv/CIlM7UzMgXO/?hl=en"
    onebox_klass = Onebox::Matcher.new(tv_link, onebox_options).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  context "with access token" do
    let(:api_link) do
      "https://graph.facebook.com/v9.0/instagram_oembed?url=#{link}&access_token=#{access_token}"
    end

    before do
      stub_request(:head, link)
      stub_request(:get, api_link).to_return(status: 200, body: onebox_response("instagram"))
      stub_request(
        :get,
        "https://api.instagram.com/oembed/?url=https://www.instagram.com/p/CARbvuYDm3Q",
      ).to_return(status: 200, body: onebox_response("instagram"))
      @previous_options = Onebox.options.to_h
      Onebox.options = { facebook_app_access_token: access_token }
    end

    after { Onebox.options = @previous_options }

    it "renders preview with a placeholder" do
      expect(Oneboxer.preview(link, invalidate_oneboxes: true)).to include("placeholder-icon image")
    end

    it "renders html using an iframe" do
      onebox = described_class.new(link)
      html = onebox.to_html

      expect(html).to include("<iframe")
    end
  end

  context "without access token" do
    let(:api_link) { "https://api.instagram.com/oembed/?url=#{link}" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:head, link)
      stub_request(:get, api_link).to_return(status: 200, body: onebox_response("instagram_old"))
      @previous_options = Onebox.options.to_h
      Onebox.options = {}
    end

    after { Onebox.options = @previous_options }

    it "renders preview with a placeholder" do
      expect(Oneboxer.preview(link, invalidate_oneboxes: true)).to include("placeholder-icon image")
    end

    it "renders html using an iframe" do
      expect(html).to include("<iframe")
    end
  end

  describe ".===" do
    it "matches valid Instagram post URL" do
      valid_url = URI("https://www.instagram.com/p/abc123xyz/")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Instagram TV URL" do
      valid_url_tv = URI("https://instagram.com/tv/abc123xyz")
      expect(described_class === valid_url_tv).to eq(true)
    end

    it "matches valid short URL from instagr.am" do
      valid_short_url = URI("https://instagr.am/p/abc123xyz/")
      expect(described_class === valid_short_url).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://instagram.com.malicious.com/p/abc123xyz")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match short URL with extra domain" do
      malicious_url = URI("https://instagr.am.malicious.com/p/abc123xyz")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.instagram.com/p/abc123xyz")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://instagram.com/invalid/abc123xyz")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/p/abc123xyz")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end

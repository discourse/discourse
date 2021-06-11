# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::InstagramOnebox do
  let(:access_token) { 'abc123' }
  let(:link) { "https://www.instagram.com/p/CARbvuYDm3Q" }

  it 'oneboxes links that include the username' do
    link_with_profile = 'https://www.instagram.com/bennyblood24/p/CARbvuYDm3Q/'
    onebox_klass = Onebox::Matcher.new(link_with_profile).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  it 'oneboxes photo links' do
    photo_link = 'https://www.instagram.com/p/CARbvuYDm3Q/'
    onebox_klass = Onebox::Matcher.new(photo_link).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  it 'oneboxes tv links' do
    tv_link = "https://www.instagram.com/tv/CIlM7UzMgXO/?hl=en"
    onebox_klass = Onebox::Matcher.new(tv_link).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  context 'with access token' do
    let(:api_link) { "https://graph.facebook.com/v9.0/instagram_oembed?url=#{link}&access_token=#{access_token}" }

    before do
      stub_request(:get, api_link).to_return(status: 200, body: onebox_response("instagram"))
      stub_request(:get, "https://api.instagram.com/oembed/?url=https://www.instagram.com/p/CARbvuYDm3Q")
        .to_return(status: 200, body: onebox_response("instagram"))
      @previous_options = Onebox.options.to_h
      Onebox.options = { facebook_app_access_token: access_token }
    end

    after do
      Onebox.options = @previous_options
    end

    it "includes title" do
      onebox = described_class.new(link)
      html = onebox.to_html

      expect(html).to include('<a href="https://www.instagram.com/p/CARbvuYDm3Q" target="_blank" rel="noopener">@natgeo</a>')
    end

    it "includes image" do
      onebox = described_class.new(link)
      html = onebox.to_html

      expect(html).to include("https://scontent.cdninstagram.com/v/t51.2885-15/sh0.08/e35/s640x640/97565241_163250548553285_9172168193050746487_n.jpg")
    end
  end

  context 'without access token' do
    let(:api_link) { "https://api.instagram.com/oembed/?url=#{link}" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, api_link).to_return(status: 200, body: onebox_response("instagram_old_onebox"))
      @previous_options = Onebox.options.to_h
      Onebox.options = {}
    end

    after do
      Onebox.options = @previous_options
    end

    it "includes title" do
      expect(html).to include('<a href="https://www.instagram.com/p/CARbvuYDm3Q" target="_blank" rel="noopener">@natgeo</a>')
    end

    it "includes image" do
      expect(html).to include("https://scontent-yyz1-1.cdninstagram.com/v/t51.2885-15/sh0.08/e35/s640x640/97565241_163250548553285_9172168193050746487_n.jpg")
    end
  end
end

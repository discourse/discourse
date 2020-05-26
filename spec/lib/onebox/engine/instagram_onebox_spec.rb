# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::InstagramOnebox do
  let(:link) { "https://www.instagram.com/p/CARbvuYDm3Q/" }
  let(:api_link) { "https://api.instagram.com/oembed/?url=https://www.instagram.com/p/CARbvuYDm3Q" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(api_link, response("instagram"))
  end

  it "includes title" do
    expect(html).to include('<a href="https://www.instagram.com/p/CARbvuYDm3Q" target="_blank" rel="noopener">@natgeo</a>')
  end

  it "includes image" do
    expect(html).to include("https://www.instagram.com/p/CARbvuYDm3Q/media/?size=l")
  end

  it "includes description" do
    expect(html).to include("Photo by Pete McBride @pedromcbride | For the first time in three decades")
  end

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
end

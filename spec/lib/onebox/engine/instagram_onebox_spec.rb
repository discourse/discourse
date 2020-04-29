# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::InstagramOnebox do
  let(:link) { "https://www.instagram.com/p/BgSPalMjddb" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("instagram"))
  end

  it "includes title" do
    expect(html).to include('<a href="https://www.instagram.com/p/BgSPalMjddb/" target="_blank" rel="noopener">National Geographic</a>')
  end

  it "includes image" do
    expect(html).to include("28751607_101336700703060_7002304208821026816_n.jpg?_nc_ht=scontent-waw1-1.cdninstagram.com&amp;_nc_cat=104&amp;_nc_ohc=NXYxExVGcLkAX8-FRp3&amp;oh=add21f207c8533dc3c254c9532b1bcca&amp;oe=5E769EDA")
  end

  it "includes description" do
    expect(html).to include("1.2m Likes, 5,971 Comments - National Geographic (@natgeo) on Instagram")
  end

  it 'oneboxes links that include the username' do
    link_with_profile = 'https://www.instagram.com/bennyblood24/p/Brc6FNRn9vu/'
    onebox_klass = Onebox::Matcher.new(link_with_profile).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end

  it 'oneboxes photo links' do
    photo_link = 'https://www.instagram.com/p/Brc6FNRn9vu/'
    onebox_klass = Onebox::Matcher.new(photo_link).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end
end

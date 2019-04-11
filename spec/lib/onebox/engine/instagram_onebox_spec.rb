require "spec_helper"

describe Onebox::Engine::InstagramOnebox do
  let(:link) { "https://www.instagram.com/p/BgSPalMjddb" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("instagram"))
  end

  it "includes title" do
    expect(html).to include('<a href="https://www.instagram.com/p/BgSPalMjddb/" target="_blank">National Geographic</a>')
  end

  it "includes image" do
    expect(html).to include("28751607_101336700703060_7002304208821026816_n.jpg")
  end

  it "includes description" do
    expect(html).to include("1.2m Likes, 6,100 Comments - National Geographic (@natgeo) on Instagram")
  end

  it 'Oneboxes links that include the username' do
    link_with_profile = 'https://www.instagram.com/bennyblood24/p/Brc6FNRn9vu/'
    onebox_klass = Onebox::Matcher.new(link_with_profile).oneboxed
    expect(onebox_klass.name).to eq(described_class.name)
  end
end

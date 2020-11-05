# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::InstagramOnebox do
  let(:link) { "https://www.instagram.com/p/CARbvuYDm3Q/" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("instagram"))
  end

  it "includes title" do
    expect(html).to include('<a href="https://www.instagram.com/p/CARbvuYDm3Q" target="_blank" rel="noopener">@natgeo</a>')
  end

  it "includes image" do
    expect(html).to include("https://scontent.cdninstagram.com/v/t51.2885-15/fr/e15/s1080x1080/97565241_163250548553285_9172168193050746487_n.jpg?_nc_ht=scontent.cdninstagram.com&amp;_nc_cat=105&amp;_nc_ohc=dN9OLDXIp88AX8OhjJy&amp;oh=fe23f001b0997b3a73f72fae3e0ef91f&amp;oe=5FBA2690")
  end

  it "includes description" do
    expect(html).to include("National Geographic on Instagram: “Photo by Pete McBride @pedromcbride")
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

  # Sometimes Instagram sends back responses with the `description` in a different format.
  # Perhaps some form of A/B testing? Make sure we handle those cases.
  context 'alternate response' do
    let(:link) { "https://www.instagram.com/p/CByPkaHAhaA/" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake(link, response("instagram_alternative"))
    end

    it "includes title" do
      expect(html).to include('<a href="https://www.instagram.com/p/CByPkaHAhaA" target="_blank" rel="noopener">@picturesontv</a>')
    end

    it "includes image" do
      expect(html).to include("https://instagram.fykz2-1.fna.fbcdn.net/v/t51.2885-15/e35/s1080x1080/104690885_607568746536223_3426942535883552192_n.jpg?_nc_ht=instagram.fykz2-1.fna.fbcdn.net&amp;_nc_cat=107&amp;_nc_ohc=2fS_olBgk34AX_eyFqt&amp;_nc_tp=15&amp;oh=d4364e8f3476a3d6065f67f374aa26b1&amp;oe=5FCA29BA")
    end

    it "includes description" do
      expect(html).to include("@picturesontv on Instagram: “Every day is a day of new opportunities....")
    end
  end
end

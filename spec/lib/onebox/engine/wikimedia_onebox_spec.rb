# frozen_string_literal: true

RSpec.describe Onebox::Engine::WikimediaOnebox do
  let(:link) { "https://commons.wikimedia.org/wiki/File:Stones_members_montage2.jpg" }
  let(:api_link) do
    "https://en.wikipedia.org/w/api.php?action=query&titles=File:Stones_members_montage2.jpg&prop=imageinfo&iilimit=50&iiprop=timestamp|user|url&iiurlwidth=500&format=json"
  end
  let(:html) { described_class.new(link).to_html }

  before { stub_request(:get, api_link).to_return(status: 200, body: onebox_response("wikimedia")) }

  it "has the title" do
    expect(html).to include("File:Stones members montage2.jpg")
  end

  it "has the link" do
    expect(html).to include(link)
  end

  it "has the image" do
    expect(html).to include(
      "https://upload.wikimedia.org/wikipedia/commons/a/af/Stones_members_montage2.jpg",
    )
  end
end

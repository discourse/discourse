require "spec_helper"

describe Onebox::Engine::GfycatOnebox do
  let(:link) { "https://gfycat.com/AmusingPoshCleanerwrasse" }
  let(:api_link) { "https://gfycat.com/cajax/get/AmusingPoshCleanerwrasse" }
  let(:html) { described_class.new(link).to_html }
  let(:placeholder_html) { described_class.new(link).placeholder_html }

  before do
    fake(api_link, response("gfycat"))
  end

  it "has the title" do
    expect(html).to include("AmusingPoshCleanerwrasse")
    expect(placeholder_html).to include("AmusingPoshCleanerwrasse")
  end

  it "has the link" do
    expect(html).to include(link)
    expect(placeholder_html).to include(link)
  end

  it "has the poster" do
    expect(html).to include("https://thumbs.gfycat.com/AmusingPoshCleanerwrasse-poster.jpg")
  end

  it "has the webm video" do
    expect(html).to include("https://fat.gfycat.com/AmusingPoshCleanerwrasse.webm")
  end

  it "has the mp4 video" do
    expect(html).to include("https://giant.gfycat.com/AmusingPoshCleanerwrasse.mp4")
  end
end

require "spec_helper"

describe Onebox::Engine::TedOnebox do
  let(:link) { "http://ted.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("ted.response"))
  end

  it "returns video title" do
    expect(html).to include("Eli Beer: The fastest ambulance? A motorcycle")
  end

  it "returns video photo" do
    expect(html).to include("aa8d0403aec3466d031e3e1c1605637d84d6a07d_389x292.jpg")
  end

  # it "returns video description" do
  #   expect(html).to include("To mark the launch of a new website for Hermann Miller furniture")
  # end

  # it "returns video URL" do
  #   expect(html).to include("http://vimeo.com/moogaloop.swf?clip_id=70437049")
  # end

  it "returns URL" do
    expect(html).to include(link)
  end
end

require "spec_helper"

describe Onebox::Engine::DailymotionOnebox do
  let(:link) { "http://dailymotion.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("dailymotion.response"))
  end

  it "returns video title" do
    expect(html).to include("Two Door Cinema Club - Les Vielles Charrues 2013.")
  end

  it "returns video image" do
    expect(html).to include("526x297-bxE.jpg")
  end

  it "returns video description" do
    expect(html).to include("Vibrez au son de l&#39;electro-pop des Irlandais de Two Door Cinema Club,")
  end

  it "returns video URL" do
    expect(html).to include("http://www.dailymotion.com/swf/video/x12h020?autoPlay=1")
  end

  it "returns video embed code"

  it "returns URL" do
    expect(html).to include(link)
  end
end

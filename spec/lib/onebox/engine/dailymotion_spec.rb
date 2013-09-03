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

  it "returns URL" do
    expect(html).to include(link)
  end
end

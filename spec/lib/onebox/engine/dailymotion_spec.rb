require "spec_helper"

describe Onebox::Engine::DailymotionOnebox do
  let(:link) { "http://dailymotion.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("dailymotion.response"))
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

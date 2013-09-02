require "spec_helper"

describe Onebox::Engine::YfrogOnebox do
  let(:link) { "http://yfrog.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("yfrog.response"))
  end

  it "returns photo title" do
    expect(html).to include("Celebrating @questlove Cook4Quest w/WyattCenac")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

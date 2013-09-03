require "spec_helper"

describe Onebox::Engine::Revision3Onebox do
  let(:link) { "http://collegehumor.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("revision3.response"))
  end

  it "returns video title" do
    expect(html).to include("Blue Shark Bites Diver&#39;s Arm")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

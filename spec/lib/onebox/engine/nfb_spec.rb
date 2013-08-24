require "spec_helper"

describe Onebox::Engine::NFBOnebox do
  let(:link) { "http://nfb.ca" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("nfb.response"))
  end

  it "returns video title" do
    expect(html).to include("Overdose")
  end

  it "returns video description" do
    expect(html).to include("With school, tennis lessons, swimming lessons, art classes,")
  end

  # it "returns video URL" do
  #   expect(html).to include("moogaloop.1.0.31.swf?clip_id=6830834&amp;use_node_id=true&amp;og=1&amp;auto=true")
  # end

  it "returns the video embed code" do
    pending
    expect(html).to include("")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

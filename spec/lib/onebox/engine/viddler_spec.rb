require "spec_helper"

describe Onebox::Engine::ViddlerOnebox do
  let(:link) { "http://viddler.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("viddler.response"))
  end

  it "returns video title" do
    expect(html).to include("Viddler Demo")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

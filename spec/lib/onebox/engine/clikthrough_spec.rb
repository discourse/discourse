require "spec_helper"

describe Onebox::Engine::ClikThroughOnebox do
  let(:link) { "http://www.clickthough.com"}
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("clikthrough.response"))
  end

  it "returns video title" do
    expect(html).to include("Keri Hilson - Knock You Down")
  end

  it "returns video description" do
    expect(html).to include("Keri Hilson gets taken down by love once again")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

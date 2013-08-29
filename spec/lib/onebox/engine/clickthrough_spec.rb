require "spec_helper"

describe Onebox::Engine::ClickThroughOnebox do
  let(:link) { "http://www.clickthough.com"}
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("clickthrough.response"))
  end

  it "returns video title" do
    expect(html).to include("Interactive Video : Keri Hilson - Knock You Down")
  end

# clickthrough.response has og tag for image but attr is blank
  it "returns video image" do
    expect(html).to include("")
  end

  it "returns video description" do
    expect(html).to include("Keri Hilson gets taken down by love once again")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

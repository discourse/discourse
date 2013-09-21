require "spec_helper"

describe Onebox::Engine::ImgurOnebox do
  let(:link) { "http://imgur.com" }
  before do
    fake(link, response("imgur"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

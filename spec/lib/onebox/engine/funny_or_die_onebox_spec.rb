require "spec_helper"

describe Onebox::Engine::FunnyOrDieOnebox do
  let(:link) { "http://funnyordie.com" }
  before do
    fake(link, response("funnyordie"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("The Landlord")
    end

    it "returns video photo" do
      expect(html).to include("c480x270_18.jpg")
    end

    it "returns video description" do
      expect(html).to include("Will Ferrell meets his landlord.")
    end

    it "returns video URL" do
      expect(html).to include("http://www.funnyordie.com/videos/74/the-landlord-from-will-ferrell-and-adam-ghost-panther-mckay")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

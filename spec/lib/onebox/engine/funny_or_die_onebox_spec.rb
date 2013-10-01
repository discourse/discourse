require "spec_helper"

describe Onebox::Engine::FunnyOrDieOnebox do
  before(:all) do
    @link = "http://funnyordie.com"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

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

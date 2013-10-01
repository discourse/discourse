require "spec_helper"

describe Onebox::Engine::NFBOnebox do
  before(:all) do
    @link = "http://www.nfb.ca/film/overdose"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Overdose")
    end

    it "returns video description" do
      expect(html).to include("With school, tennis lessons, swimming lessons, art classes,")
    end

    it "returns video URL" do
      expect(html).to include("http://www.nfb.ca/film/overdose_en/")
    end

    it "returns the video embed code" do
      pending
      expect(html).to include("")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

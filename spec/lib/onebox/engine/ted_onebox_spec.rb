require "spec_helper"

describe Onebox::Engine::TedOnebox do
  before(:all) do
    @link = "http://www.ted.com/talks/eli_beer_the_fastest_ambulance_a_motorcycle.html"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Eli Beer: The fastest ambulance? A motorcycle")
    end

    it "returns video photo" do
      expect(html).to include("aa8d0403aec3466d031e3e1c1605637d84d6a07d_389x292.jpg")
    end

    it "returns video description" do
      expect(html).to include("As a young EMT on a Jerusalem ambulance")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

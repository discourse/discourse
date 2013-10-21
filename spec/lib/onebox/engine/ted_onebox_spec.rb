require "spec_helper"

describe Onebox::Engine::TedOnebox do
  before(:all) do
    @link = "http://www.ted.com/talks/eli_beer_the_fastest_ambulance_a_motorcycle.html"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has still" do
      expect(html).to include("aa8d0403aec3466d031e3e1c1605637d84d6a07d_389x292.jpg")
    end

    it "has description" do
      expect(html).to include("As a young EMT on a Jerusalem ambulance")
    end
  end
end

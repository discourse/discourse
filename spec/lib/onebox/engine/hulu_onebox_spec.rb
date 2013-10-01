require "spec_helper"

describe Onebox::Engine::HuluOnebox do
  before(:all) do
    @link = "http://www.hulu.com/watch/515146"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("The Awesomes: Pilot, Part 1")
    end

    it "returns photo" do
      expect(html).to include("http://ib3.huluim.com/video/60245466?region=US&amp;size=600x400")
    end

    it "returns video description" do
      expect(html).to include("After Mr. Awesome decides to retire and disband The Awesomes")
    end

    it "returns video URL" do
      expect(html).to include("https://secure.hulu.com/embed/0-us7uHJgevua5TeiGwCxQ")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

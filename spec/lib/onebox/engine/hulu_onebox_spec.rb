require "spec_helper"

describe Onebox::Engine::HuluOnebox do
  before(:all) do
    @link = "http://www.hulu.com/watch/515146"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("http://ib3.huluim.com/video/60245466?region=US&amp;size=600x400")
    end

    it "includes description" do
      expect(html).to include("After Mr. Awesome decides to retire and disband The Awesomes")
    end

    it "includes embedded video link" do
      expect(html).to include("https://secure.hulu.com/embed/0-us7uHJgevua5TeiGwCxQ")
    end
  end
end

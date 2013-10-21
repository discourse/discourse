require "spec_helper"

describe Onebox::Engine::Revision3Onebox do
  before(:all) do
    @link = "http://revision3.com/discoverysharks/blue-sharks"
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
      expect(html).to include("discoverysharks--0029--blue-sharks--medium.thumb.jpg")
    end

    it "includes description" do
      expect(html).to include("Blue Sharks swimming and eating in the open ocean.")
    end

    it "includes embedded video link" do
      expect(html).to include("https://revision3.com/player-v22668")
    end

    it "returns video embed code"
  end
end

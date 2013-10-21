require "spec_helper"

describe Onebox::Engine::FunnyOrDieOnebox do
  before(:all) do
    @link = "http://www.funnyordie.com/videos/74/the-landlord-from-will-ferrell-and-adam-ghost-panther-mckay"
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
      expect(html).to include("c480x270_18.jpg")
    end

    it "includes description" do
      expect(html).to include("Will Ferrell meets his landlord.")
    end
  end
end

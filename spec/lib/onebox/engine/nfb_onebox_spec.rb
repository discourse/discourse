require "spec_helper"

describe Onebox::Engine::NFBOnebox do
  before(:all) do
    @link = "http://www.nfb.ca/film/overdose"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes description" do
      expect(html).to include("With school, tennis lessons, swimming lessons, art classes,")
    end

    it "includes video embedded link" do
      pending
      expect(html).to include("")
    end
  end
end

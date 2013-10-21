require "spec_helper"

describe Onebox::Engine::QikOnebox do
  before(:all) do
    @link = "http://qik.com/video/13430626"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has author" do
      expect(html).to include("mitesh patel")
    end

    it "has still" do
      expect(html).to include("me_large.jpg")
    end

    it "has embedded video link" do
      pending
      expect(html).to include("clsid:d27cdb6e-ae6d-11cf-96b8-444553540000")
    end
  end
end

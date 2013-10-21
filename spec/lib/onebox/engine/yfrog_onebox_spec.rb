require "spec_helper"

describe Onebox::Engine::YfrogOnebox do
  before(:all) do
    @link = "http://twitter.yfrog.com/h0jjdobj?sa=0"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has photo" do
      expect(html).to include("jjdob.jpg")
    end

    it "has description" do
      expect(html).to include("Click on the photo to comment, share or view other great photos")
    end
  end
end

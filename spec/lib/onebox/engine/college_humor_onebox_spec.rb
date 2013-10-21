require "spec_helper"

describe Onebox::Engine::CollegeHumorOnebox do
  before(:all) do
    @link = "http://collegehumor.com"
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
      expect(html).to include("a9febe641d5beb264bbab0de49272e5a-mitt-romney-style-gangnam-style-parody.jpg")
    end

    it "has description" do
      expect(html).to include("Heyyy wealthy ladies!&quot;Mitt Romney Style&quot; is now available on iTunes")
    end

    it "has embedded video link" do
      expect(html).to include("moogaloop.1.0.31.swf?clip_id=6830834&amp;use_node_id=true&amp;og=1&amp;auto=true")
    end
  end
end

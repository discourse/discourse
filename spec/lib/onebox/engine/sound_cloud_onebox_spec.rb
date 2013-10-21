require "spec_helper"

describe Onebox::Engine::SoundCloudOnebox do
  before(:all) do
    @link = "https://soundcloud.com/rac/penguin-prison-worse-it-gets-rac-mix"
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
      expect(html).to include("artworks-000033643332-vpuznu-t500x500.jpg")
    end

    it "has description" do
      expect(html).to include("Remix by André Allen Anjos.")
    end

    it "has embedded video link"
  end
end

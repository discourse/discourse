require "spec_helper"

describe Onebox::Engine::SoundCloudOnebox do
  before(:all) do
    @link = "https://soundcloud.com/rac/penguin-prison-worse-it-gets-rac-mix"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Penguin Prison - Worse It Gets (RAC Mix)")
    end

    it "returns video image" do
      expect(html).to include("artworks-000033643332-vpuznu-t500x500.jpg")
    end

    it "returns video description" do
      expect(html).to include("Remix by André Allen Anjos.")
    end

    it "returns video URL" do
      expect(html).to include("Remix by André Allen Anjos.")
    end

    it "returns video embed code"

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

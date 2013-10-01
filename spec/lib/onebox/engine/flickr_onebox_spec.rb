require "spec_helper"

describe Onebox::Engine::FlickrOnebox do
  before(:all) do
    @link = "http://flickr.com"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns photo title" do
      expect(html).to include("Los Angeles View 2011")
    end

    it "returns photo" do
      expect(html).to include("6038315155_2875860c4b_z.jpg")
    end

    it "returns photo description" do
      expect(html).to include("The view from the Griffith Observatory, Los Angeles; July 2011")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

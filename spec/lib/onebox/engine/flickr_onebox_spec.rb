require "spec_helper"

describe Onebox::Engine::FlickrOnebox do
  before(:all) do
    @link = "http://flickr.com"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes photo" do
      expect(html).to include("6038315155_2875860c4b_z.jpg")
    end

    it "includes description" do
      expect(html).to include("The view from the Griffith Observatory, Los Angeles; July 2011")
    end
  end
end

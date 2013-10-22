require "spec_helper"

describe Onebox::Engine::FlickrOnebox do
  before(:all) do
    @link = "http://flickr.com"
  end

  include_context "engines"
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

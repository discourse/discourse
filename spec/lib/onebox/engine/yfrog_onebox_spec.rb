require "spec_helper"

describe Onebox::Engine::YfrogOnebox do
  before(:all) do
    @link = "http://twitter.yfrog.com/h0jjdobj?sa=0"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes photo" do
      expect(html).to include("jjdob.jpg")
    end

    it "includes description" do
      expect(html).to include("Click on the photo to comment, share or view other great photos")
    end
  end
end

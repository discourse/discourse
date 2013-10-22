require "spec_helper"

describe Onebox::Engine::QikOnebox do
  before(:all) do
    @link = "http://qik.com/video/13430626"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes author" do
      expect(html).to include("mitesh patel")
    end

    it "includes still" do
      expect(html).to include("me_large.jpg")
    end

    it "includes embedded video link" do
      pending
      expect(html).to include("clsid:d27cdb6e-ae6d-11cf-96b8-444553540000")
    end
  end
end

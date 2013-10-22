require "spec_helper"

describe Onebox::Engine::FunnyOrDieOnebox do
  before(:all) do
    @link = "http://www.funnyordie.com/videos/74/the-landlord-from-will-ferrell-and-adam-ghost-panther-mckay"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("c480x270_18.jpg")
    end

    it "includes description" do
      expect(html).to include("Will Ferrell meets his landlord.")
    end
  end
end

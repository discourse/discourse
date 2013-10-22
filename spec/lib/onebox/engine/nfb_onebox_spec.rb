require "spec_helper"

describe Onebox::Engine::NFBOnebox do
  before(:all) do
    @link = "http://www.nfb.ca/film/overdose"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes description" do
      expect(html).to include("With school, tennis lessons, swimming lessons, art classes,")
    end

    it "includes video embedded link" do
      pending
      expect(html).to include("")
    end
  end
end

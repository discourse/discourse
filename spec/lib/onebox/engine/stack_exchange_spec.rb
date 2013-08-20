require "spec_helper"

describe Onebox::Engine::StackExchangeOnebox do
  describe "#to_html" do
    let(:link) { "http://stackexchange.com" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake(link, response("stackexchange.response"))
    end

    it "returns the question title" do
      expect(html).to include("Concept behind these 4 lines of tricky C++ code")
    end

    it "returns the question" do
      expect(html).to include("Why does this code gives output C++Sucks? Can anyone explain the concept behind it?")
    end

    it "returns the question URL" do
      expect(html).to include(link)
    end
  end
end


require "spec_helper"

describe Onebox::Preview::StackExchange do
  describe "#to_html" do
    let(:link) { "http://stackexchange.com" }

    it "returns the question title" do
      stackexchange = described_class.new(response("stackexchange.response"), link)
      expect(stackexchange.to_html).to include("Concept behind these 4 lines of tricky C++ code")
    end

    it "returns the question" do
      stackexchange = described_class.new(response("stackexchange.response"), link)
      expect(stackexchange.to_html).to include("Why does this code gives output C++Sucks? Can anyone explain the concept behind it?")
    end

    it "returns the question URL" do
      stackexchange = described_class.new(response("stackexchange.response"), link)
      expect(stackexchange.to_html).to include(link)
    end
  end
end

require "spec_helper"

describe Onebox::Matcher do
  describe "#oneboxed" do
    it "returns Example onebox when given example url" do
      matcher = described_class.new("http://example.com")
      expect(matcher.oneboxed).to be(Onebox::Engine::Example)
    end

    it "returns Amazon onebox when given amazon url" do
      matcher = described_class.new("http://amazon.com")
      expect(matcher.oneboxed).to be(Onebox::Engine::Amazon)
    end
  end
end

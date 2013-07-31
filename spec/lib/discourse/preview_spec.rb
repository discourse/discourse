require "spec_helper"

describe Discourse::Oneboxer::Preview do
  describe "#to_s" do
    it "returns some html if given a valid url" do
      # fake("http://example.com", "<b></b>")
      preview = described_class.new("http://example.com")
      expect(preview.to_s).to eq(onebox_view("<h1>Example Domain</h1>"))

      # fake("http://www.example.com", "<i></i>")
      preview = described_class.new("http://www.example.com")
      expect(preview.to_s).to eq(onebox_view("<h1>Example Domain</h1>"))
    end
  end
end

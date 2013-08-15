require "spec_helper"

describe Onebox::Engine::Example do
  describe "#to_html" do
    it "returns template if given valid data" do
      example = described_class.new(response("example.response"), "http://www.example.com")
      expect(example.to_html).to include(onebox_view("<h1>Example Domain 1</h1>"))
    end
  end
end

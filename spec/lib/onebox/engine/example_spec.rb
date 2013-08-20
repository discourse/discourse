require "spec_helper"

describe Onebox::Engine::Example do
  describe "#to_html" do
    let(:link) { "http://example.com" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake(link, response("example.response"))
    end

    it "returns template if given valid data" do
      expect(html).to include(onebox_view("<h1>Example Domain 1</h1>"))
    end
  end
end

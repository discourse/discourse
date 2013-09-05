require "spec_helper"

describe Onebox::Engine::ExampleOnebox do
  let(:link) { "http://example.com" }

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    before do
      fake(link, response("example.response"))
    end

    it "returns template if given valid data" do
      expect(html).to include(onebox_view("Example Domain 1"))
    end
  end
end

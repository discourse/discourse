require "spec_helper"

describe Onebox::Engine::ExampleOnebox do
  let(:link) { "http://example.com" }
  before do
    fake(link, response("example"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns template if given valid data" do
      expect(html).to include(onebox_view("Example Domain 1"))
    end
  end
end

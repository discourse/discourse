require "spec_helper"

describe Onebox::Engine::ExampleOnebox do
  before(:all) do
    @link = "http://example.com"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns template if given valid data" do
      expect(html).to include("Example Domain 1")
    end
  end
end

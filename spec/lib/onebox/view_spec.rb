require "spec_helper"

describe Onebox::View do
  let(:view) { described_class.new("amazon", true) }
  let(:html) { view.to_html(link: "http://amazon.com") }

  describe "#to_html" do
    it "renders engine partial within layout template" do
      expect(html).to include(%|class="onebox|)
    end
  end
end

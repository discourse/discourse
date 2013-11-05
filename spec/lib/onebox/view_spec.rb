require "spec_helper"

describe Onebox::View do

  describe "#to_html" do
    it "renders record values" do
      record = { name: "bleh" }
      html = described_class.new("amazon", record).to_html
      expect(html).to include("bleh")
    end
  end
end

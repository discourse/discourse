require "spec_helper"

describe Onebox::Layout do
  let(:view) { described_class.new("amazon", true) }
  let(:html) { view.to_html(link: "http://amazon.com") }

  describe "#to_html" do
    it "contains layout template" do
      expect(html).to include(%|class="onebox|)
    end

    it "stores rendered template if it isn't cached" do
      expect(html).to include(%|""|)
    end

    it "reads from cache if rendered template is cached" do
      expect(html).to include(%|""|)
    end

    it "contains the view" do
      expect(html).to include(%|""|)
    end
  end

  describe "#checksum" do
    it "generates a checksum from template version and resource url" do
      expect(result).to eq("")
    end
  end
end

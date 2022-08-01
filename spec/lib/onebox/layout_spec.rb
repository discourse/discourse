# frozen_string_literal: true

RSpec.describe Onebox::Layout do
  let(:record) { {} }
  let(:layout) { described_class.new("amazon", record) }
  let(:html) { layout.to_html }

  describe "#to_html" do
    it "contains layout template" do
      expect(html).to include(%|class="onebox|)
    end

    it "contains the view" do
      record = { link: "foo" }
      html = described_class.new("amazon", record).to_html
      expect(html).to include(%|"foo"|)
    end

    it "rewrites relative image path" do
      record = { image: "/image.png", link: "https://discourse.org" }
      klass = described_class.new("allowlistedgeneric", record)
      expect(klass.view.record[:image]).to include("https://discourse.org")
    end
  end
end

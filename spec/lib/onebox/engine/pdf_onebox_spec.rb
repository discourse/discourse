require "spec_helper"

describe Onebox::Engine::PdfOnebox do
  let(:link) { "https://acrobatusers.com/assets/uploads/public_downloads/2217/adobe-acrobat-xi-merge-pdf-files-tutorial-ue.pdf" }
  let(:html) { described_class.new(link).to_html }

  before do
    FakeWeb.register_uri(:head, link, :content_length => "335562")
  end

  describe "#to_html" do
    it "includes filename" do
      expect(html).to include("adobe-acrobat-xi-merge-pdf-files-tutorial-ue.pdf")
    end

    it "includes filesize" do
      expect(html).to include("327.70 KB")
    end
  end
end

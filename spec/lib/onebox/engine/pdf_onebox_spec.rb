require "spec_helper"

describe Onebox::Engine::PdfOnebox do
  let(:link) { "https://acrobatusers.com/assets/uploads/public_downloads/2217/adobe-acrobat-xi-merge-pdf-files-tutorial-ue.pdf" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("pdf"))
  end

  describe "#to_html" do
    it "includes title" do
      expect(html).to include("Merge multiple files into one PDF file with Acrobat XI")
    end

    it "includes description" do
      expect(html).to include("Learn more about Adobe Acrobat XI: Merge multiple files into one PDF file with Acrobat XI")
    end

    it "includes author" do
      expect(html).to include("Adobe Systems, Inc.")
    end
  end
end

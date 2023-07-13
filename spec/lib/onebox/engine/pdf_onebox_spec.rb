# frozen_string_literal: true

RSpec.describe Onebox::Engine::PdfOnebox do
  let(:link) do
    "https://acrobatusers.com/assets/uploads/public_downloads/2217/adobe-acrobat-xi-merge-pdf-files-tutorial-ue.pdf"
  end
  let(:html) { described_class.new(link).to_html }

  let(:no_content_length_link) do
    "https://dspace.lboro.ac.uk/dspace-jspui/bitstream/2134/14294/3/greiffenhagen-ca_and_consumption.pdf"
  end
  let(:no_filesize_html) { described_class.new(no_content_length_link).to_html }

  before do
    stub_request(:head, link).to_return(status: 200, headers: { "Content-Length" => "335562" })
    stub_request(:head, no_content_length_link).to_return(status: 200)
  end

  describe "#to_html" do
    it "includes filename" do
      expect(html).to include("adobe-acrobat-xi-merge-pdf-files-tutorial-ue.pdf")
    end

    it "includes filesize" do
      expect(html).to include("327.70 KB")
    end

    it "doesn’t include filesize when unknown" do
      expect(no_filesize_html).to_not include("<p class='filesize'>")
    end
  end
end

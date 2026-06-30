# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::PdfToText do
  let(:pdf) { plugin_file_from_fixtures("2-page.pdf", "rag") }
  let(:upload) { UploadCreator.new(pdf, "2-page.pdf").create_for(Discourse.system_user.id) }

  before do
    enable_current_plugin
    SiteSetting.authorized_extensions = "pdf|png|jpg|jpeg"
  end

  describe "#extract_text" do
    xit "extracts text from PDF pages" do
      pdf_to_text = described_class.new(upload: upload)
      pages = []
      pdf_to_text.extract_text { |page| pages << page }

      expect(pages).to eq(["Page 1", "Page 2"])
    end
  end
end

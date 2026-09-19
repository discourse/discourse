# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::DocumentEncoder do
  before { enable_current_plugin }

  describe ".attachment_type_for" do
    {
      "pdf" => "pdf",
      "docx" => "docx",
      "doc" => "doc",
      "xlsx" => "xlsx",
      "xls" => "xls",
      "odt" => "odt",
      "ods" => "ods",
      "csv" => "csv",
      "txt" => "txt",
      "rtf" => "rtf",
      "html" => "html",
      "htm" => "html",
      "md" => "md",
      "markdown" => "md",
    }.each do |extension, expected|
      it "maps .#{extension} to #{expected}" do
        mime = MiniMime.lookup_by_filename("sample.#{extension}")&.content_type.to_s

        expect(described_class.attachment_type_for(extension, mime)).to eq(expected)
        expect(described_class.attachment_type_for(".#{extension.upcase}", mime)).to eq(expected)
      end
    end

    it "falls back to the mime type when the extension is unknown" do
      expect(described_class.attachment_type_for("", "application/pdf")).to eq("pdf")
      expect(described_class.attachment_type_for("bin", "text/plain")).to eq("txt")
      expect(described_class.attachment_type_for("bin", "application/vnd.ms-excel")).to eq("xls")
    end

    it "prefers a known extension over the mime type" do
      expect(described_class.attachment_type_for("txt", "application/pdf")).to eq("txt")
    end

    it "returns the unknown sentinel for anything else" do
      expect(described_class.attachment_type_for("zip", "application/zip")).to eq("file")
      expect(described_class.attachment_type_for("", "")).to eq("file")
    end
  end
end

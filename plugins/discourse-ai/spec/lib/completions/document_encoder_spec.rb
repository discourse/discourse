# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::DocumentEncoder do
  before { enable_current_plugin }

  describe ".attachment_type_for" do
    it "maps .pdf to pdf" do
      mime = MiniMime.lookup_by_filename("sample.pdf")&.content_type.to_s

      expect(described_class.attachment_type_for("pdf", mime)).to eq("pdf")
      expect(described_class.attachment_type_for(".PDF", mime)).to eq("pdf")
    end

    it "maps .docx to docx" do
      mime = MiniMime.lookup_by_filename("sample.docx")&.content_type.to_s

      expect(described_class.attachment_type_for("docx", mime)).to eq("docx")
      expect(described_class.attachment_type_for(".DOCX", mime)).to eq("docx")
    end

    it "maps .doc to doc" do
      mime = MiniMime.lookup_by_filename("sample.doc")&.content_type.to_s

      expect(described_class.attachment_type_for("doc", mime)).to eq("doc")
      expect(described_class.attachment_type_for(".DOC", mime)).to eq("doc")
    end

    it "maps .xlsx to xlsx" do
      mime = MiniMime.lookup_by_filename("sample.xlsx")&.content_type.to_s

      expect(described_class.attachment_type_for("xlsx", mime)).to eq("xlsx")
      expect(described_class.attachment_type_for(".XLSX", mime)).to eq("xlsx")
    end

    it "maps .xls to xls" do
      mime = MiniMime.lookup_by_filename("sample.xls")&.content_type.to_s

      expect(described_class.attachment_type_for("xls", mime)).to eq("xls")
      expect(described_class.attachment_type_for(".XLS", mime)).to eq("xls")
    end

    it "maps .odt to odt" do
      mime = MiniMime.lookup_by_filename("sample.odt")&.content_type.to_s

      expect(described_class.attachment_type_for("odt", mime)).to eq("odt")
      expect(described_class.attachment_type_for(".ODT", mime)).to eq("odt")
    end

    it "maps .ods to ods" do
      mime = MiniMime.lookup_by_filename("sample.ods")&.content_type.to_s

      expect(described_class.attachment_type_for("ods", mime)).to eq("ods")
      expect(described_class.attachment_type_for(".ODS", mime)).to eq("ods")
    end

    it "maps .csv to csv" do
      mime = MiniMime.lookup_by_filename("sample.csv")&.content_type.to_s

      expect(described_class.attachment_type_for("csv", mime)).to eq("csv")
      expect(described_class.attachment_type_for(".CSV", mime)).to eq("csv")
    end

    it "maps .txt to txt" do
      mime = MiniMime.lookup_by_filename("sample.txt")&.content_type.to_s

      expect(described_class.attachment_type_for("txt", mime)).to eq("txt")
      expect(described_class.attachment_type_for(".TXT", mime)).to eq("txt")
    end

    it "maps .rtf to rtf" do
      mime = MiniMime.lookup_by_filename("sample.rtf")&.content_type.to_s

      expect(described_class.attachment_type_for("rtf", mime)).to eq("rtf")
      expect(described_class.attachment_type_for(".RTF", mime)).to eq("rtf")
    end

    it "maps .html to html" do
      mime = MiniMime.lookup_by_filename("sample.html")&.content_type.to_s

      expect(described_class.attachment_type_for("html", mime)).to eq("html")
      expect(described_class.attachment_type_for(".HTML", mime)).to eq("html")
    end

    it "maps .htm to html" do
      mime = MiniMime.lookup_by_filename("sample.htm")&.content_type.to_s

      expect(described_class.attachment_type_for("htm", mime)).to eq("html")
      expect(described_class.attachment_type_for(".HTM", mime)).to eq("html")
    end

    it "maps .md to md" do
      mime = MiniMime.lookup_by_filename("sample.md")&.content_type.to_s

      expect(described_class.attachment_type_for("md", mime)).to eq("md")
      expect(described_class.attachment_type_for(".MD", mime)).to eq("md")
    end

    it "maps .markdown to md" do
      mime = MiniMime.lookup_by_filename("sample.markdown")&.content_type.to_s

      expect(described_class.attachment_type_for("markdown", mime)).to eq("md")
      expect(described_class.attachment_type_for(".MARKDOWN", mime)).to eq("md")
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

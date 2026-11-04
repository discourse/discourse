# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::DocumentEncoder do
  before { enable_current_plugin }

  describe ".attachment_type_for" do
    shared_examples "recognizing a document extension" do |extension:, expected_type:|
      it "recognizes normal and uppercase extensions" do
        mime = MiniMime.lookup_by_filename("sample.#{extension}")&.content_type.to_s

        expect(described_class.attachment_type_for(extension, mime)).to eq(expected_type)
        expect(described_class.attachment_type_for(".#{extension.upcase}", mime)).to eq(
          expected_type,
        )
      end
    end

    context "with the pdf extension" do
      include_examples "recognizing a document extension", extension: "pdf", expected_type: "pdf"
    end

    context "with the docx extension" do
      include_examples "recognizing a document extension", extension: "docx", expected_type: "docx"
    end

    context "with the doc extension" do
      include_examples "recognizing a document extension", extension: "doc", expected_type: "doc"
    end

    context "with the xlsx extension" do
      include_examples "recognizing a document extension", extension: "xlsx", expected_type: "xlsx"
    end

    context "with the xls extension" do
      include_examples "recognizing a document extension", extension: "xls", expected_type: "xls"
    end

    context "with the odt extension" do
      include_examples "recognizing a document extension", extension: "odt", expected_type: "odt"
    end

    context "with the ods extension" do
      include_examples "recognizing a document extension", extension: "ods", expected_type: "ods"
    end

    context "with the csv extension" do
      include_examples "recognizing a document extension", extension: "csv", expected_type: "csv"
    end

    context "with the txt extension" do
      include_examples "recognizing a document extension", extension: "txt", expected_type: "txt"
    end

    context "with the rtf extension" do
      include_examples "recognizing a document extension", extension: "rtf", expected_type: "rtf"
    end

    context "with the html extension" do
      include_examples "recognizing a document extension", extension: "html", expected_type: "html"
    end

    context "with the htm extension" do
      include_examples "recognizing a document extension", extension: "htm", expected_type: "html"
    end

    context "with the md extension" do
      include_examples "recognizing a document extension", extension: "md", expected_type: "md"
    end

    context "with the markdown extension" do
      include_examples "recognizing a document extension",
                       extension: "markdown",
                       expected_type: "md"
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

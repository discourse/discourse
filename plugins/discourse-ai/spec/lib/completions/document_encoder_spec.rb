# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::DocumentEncoder do
  before { enable_current_plugin }

  describe ".attachment_type_for" do
    shared_examples "document encoder for extension and expected" do |extension, expected|
      it "maps .#{extension} to #{expected}" do
        mime = MiniMime.lookup_by_filename("sample.#{extension}")&.content_type.to_s

        expect(described_class.attachment_type_for(extension, mime)).to eq(expected)
        expect(described_class.attachment_type_for(".#{extension.upcase}", mime)).to eq(expected)
      end
    end

    include_examples "document encoder for extension and expected", %w[pdf pdf]
    include_examples "document encoder for extension and expected", %w[docx docx]
    include_examples "document encoder for extension and expected", %w[doc doc]
    include_examples "document encoder for extension and expected", %w[xlsx xlsx]
    include_examples "document encoder for extension and expected", %w[xls xls]
    include_examples "document encoder for extension and expected", %w[odt odt]
    include_examples "document encoder for extension and expected", %w[ods ods]
    include_examples "document encoder for extension and expected", %w[csv csv]
    include_examples "document encoder for extension and expected", %w[txt txt]
    include_examples "document encoder for extension and expected", %w[rtf rtf]
    include_examples "document encoder for extension and expected", %w[html html]
    include_examples "document encoder for extension and expected", %w[htm html]
    include_examples "document encoder for extension and expected", %w[md md]
    include_examples "document encoder for extension and expected", %w[markdown md]

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

# frozen_string_literal: true

require "zip"

RSpec.describe DiscourseAi::Completions::UploadEncoder do
  let(:gif) { plugin_file_from_fixtures("1x1.gif") }
  let(:jpg) { plugin_file_from_fixtures("1x1.jpg") }
  let(:webp) { plugin_file_from_fixtures("1x1.webp") }

  before { enable_current_plugin }

  def create_doc_upload(contents: "raw doc bytes", filename: "sample.doc")
    extension = File.extname(filename)
    tempfile = Tempfile.new([File.basename(filename, extension), extension.presence || ".upload"])
    tempfile.binmode
    tempfile.write(contents)
    tempfile.rewind

    UploadCreator.new(tempfile, filename).create_for(Discourse.system_user.id)
  ensure
    tempfile&.close!
  end

  def zip_bytes(entries, extension)
    tempfile = Tempfile.new(["sample", extension])
    path = tempfile.path
    tempfile.close
    FileUtils.rm_f(path)

    ::Zip::File.open(path, create: true) do |zip_file|
      entries.each do |name, content|
        zip_file.get_output_stream(name) { |stream| stream.write(content) }
      end
    end

    File.binread(path)
  ensure
    tempfile&.close
    FileUtils.rm_f(path) if path
  end

  def docx_bytes(entries)
    zip_bytes(entries, ".docx")
  end

  def xlsx_bytes(entries)
    zip_bytes(entries, ".xlsx")
  end

  def docx_document_xml(text)
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>#{text}</w:t></w:r></w:p>
        </w:body>
      </w:document>
    XML
  end

  it "automatically converts gifs to pngs" do
    upload = UploadCreator.new(gif, "1x1.gif").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end

  it "automatically converts webp to pngs" do
    upload = UploadCreator.new(webp, "1x1.webp").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end

  it "supports jpg" do
    upload = UploadCreator.new(jpg, "1x1.jpg").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/jpeg")
  end

  describe ".doc, .docx, .xls, and .xlsx uploads" do
    before { SiteSetting.authorized_extensions = "*" }

    it "converts .doc files to text" do
      upload = create_doc_upload(contents: "raw doc bytes", filename: "sample.doc")

      allow(DiscourseAi::Completions::DocToText).to receive(:convert).and_return(
        "Converted document text\n",
      )

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["doc"],
        )

      expect(DiscourseAi::Completions::DocToText).to have_received(:convert).with(
        a_string_matching(/\.doc\z/),
      )
      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.doc",
        mime_type: "text/plain",
        converted_from: "doc",
      )
      expect(encoded.first[:text]).to start_with("Uploaded document: sample.doc (")
      expect(encoded.first[:text]).to include("\n\nConverted document text")
      expect(encoded.first).not_to have_key(:base64)
    end

    it "skips .doc files when conversion is unavailable" do
      upload = create_doc_upload(contents: "raw doc bytes", filename: "sample.doc")

      allow(DiscourseAi::Completions::DocToText).to receive(:convert).and_return(nil)
      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["doc"],
        )

      expect(encoded).to be_empty
      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Skipping .doc upload",
          "raw upload is not supported for this attachment type; it must be converted to text",
        ),
      )
      expect(DiscourseAi::Completions::DocToText).to have_received(:convert).with(
        a_string_matching(/\.doc\z/),
      )
    end

    it "converts .docx files to text" do
      upload =
        create_doc_upload(
          contents:
            docx_bytes("word/document.xml" => docx_document_xml("Converted DOCX document text")),
          filename: "sample.docx",
        )

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["docx"],
        )

      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.docx",
        mime_type: "text/plain",
        converted_from: "docx",
      )
      expect(encoded.first[:text]).to start_with("Uploaded document: sample.docx (")
      expect(encoded.first[:text]).to include("\n\nConverted DOCX document text")
      expect(encoded.first).not_to have_key(:base64)
    end

    it "logs docx conversion failures and skips the upload" do
      upload = create_doc_upload(contents: "raw docx bytes", filename: "sample.docx")

      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["docx"],
        )

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Failed to convert .docx upload to text",
          "upload_id=#{upload.id}",
          "sample.docx",
          "Zip",
        ),
      )
      expect(encoded).to be_empty
    end

    it "converts .xls files to text" do
      upload = create_doc_upload(contents: "raw xls bytes", filename: "sample.xls")

      allow(DiscourseAi::Completions::XlsToText).to receive(:convert).and_return(
        "Name,Value\nAlice,1\n",
      )

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["xls"],
        )

      expect(DiscourseAi::Completions::XlsToText).to have_received(:convert).with(
        a_string_matching(/\.xls\z/),
      )
      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.xls",
        mime_type: "text/plain",
        converted_from: "xls",
      )
      expect(encoded.first[:text]).to start_with("Uploaded document: sample.xls (")
      expect(encoded.first[:text]).to include("\n\nName,Value\nAlice,1")
      expect(encoded.first).not_to have_key(:base64)
    end

    it "skips .xls files when conversion is unavailable" do
      upload = create_doc_upload(contents: "raw xls bytes", filename: "sample.xls")

      allow(DiscourseAi::Completions::XlsToText).to receive(:convert).and_return(nil)
      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["xls"],
        )

      expect(encoded).to be_empty
      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Skipping .xls upload",
          "raw upload is not supported for this attachment type; it must be converted to text",
        ),
      )
      expect(DiscourseAi::Completions::XlsToText).to have_received(:convert).with(
        a_string_matching(/\.xls\z/),
      )
    end

    it "converts .xlsx files to text" do
      upload =
        create_doc_upload(
          contents: xlsx_bytes("xl/worksheets/sheet1.xml" => <<~XML),
                <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                  <sheetData>
                    <row><c t="inlineStr"><is><t>Converted XLSX spreadsheet text</t></is></c></row>
                  </sheetData>
                </worksheet>
              XML
          filename: "sample.xlsx",
        )

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["xlsx"],
        )

      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.xlsx",
        mime_type: "text/plain",
        converted_from: "xlsx",
      )
      expect(encoded.first[:text]).to start_with("Uploaded document: sample.xlsx (")
      expect(encoded.first[:text]).to include(
        "\n\nSheet: Sheet1\n\nConverted XLSX spreadsheet text",
      )
      expect(encoded.first).not_to have_key(:base64)
    end

    it "logs xlsx conversion failures and skips the upload" do
      upload = create_doc_upload(contents: "raw xlsx bytes", filename: "sample.xlsx")

      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["xlsx"],
        )

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Failed to convert .xlsx upload to text",
          "upload_id=#{upload.id}",
          "sample.xlsx",
          "Zip",
        ),
      )
      expect(encoded).to be_empty
    end

    it "converts .rtf files to text" do
      upload =
        create_doc_upload(
          contents: "{\\rtf1\\ansi RTF {\\b document}\\par text}",
          filename: "sample.rtf",
        )

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["rtf"],
        )

      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.rtf",
        mime_type: "text/plain",
        converted_from: "rtf",
      )
      expect(encoded.first[:text]).to include("\n\nRTF document\ntext")
      expect(encoded.first).not_to have_key(:base64)
    end

    it "embeds text, markdown, and csv uploads as text" do
      uploads = [
        create_doc_upload(contents: "plain text with unicode café", filename: "notes.txt"),
        create_doc_upload(
          contents:
            "# Heading

markdown body",
          filename: "guide.md",
        ),
        create_doc_upload(
          contents:
            "name,value
Alice,1",
          filename: "data.csv",
        ),
      ]

      encoded =
        described_class.encode(
          upload_ids: uploads.map(&:id),
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: %w[txt md csv],
        )

      expect(encoded.map { |payload| payload[:converted_from] }).to eq(%w[txt md csv])
      expect(encoded).to all(include(kind: :document, mime_type: "text/plain"))
      expect(encoded).to all(satisfy { |payload| !payload.key?(:base64) })
      expect(encoded[0][:text]).to include(
        "

plain text with unicode café",
      )
      expect(encoded[1][:text]).to include(
        "

# Heading

markdown body",
      )
      expect(encoded[2][:text]).to include(
        "

name,value
Alice,1",
      )
    end

    it "accepts legacy aliases for attachment types" do
      md_upload = create_doc_upload(contents: "# Heading", filename: "guide.md")
      txt_upload = create_doc_upload(contents: "plain text", filename: "notes.txt")

      encoded =
        described_class.encode(
          upload_ids: [md_upload.id, txt_upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: %w[markdown text],
        )

      expect(encoded.map { |payload| payload[:converted_from] }).to eq(%w[md txt])
      expect(encoded.first[:text]).to include("\n\n# Heading")
      expect(encoded.second[:text]).to include("\n\nplain text")
    end

    it "limits text upload reads before embedding" do
      upload = create_doc_upload(contents: "0123456789abcdef", filename: "large.txt")

      encoded =
        stub_const(described_class, :MAX_TEXT_FILE_BYTES, 10) do
          described_class.encode(
            upload_ids: [upload.id],
            max_pixels: 1_048_576,
            allowed_kinds: %i[document],
            allowed_attachment_types: ["txt"],
          )
        end

      expect(encoded.length).to eq(1)
      expect(encoded.first[:text]).to include(
        "\n\n0123456789\n\n[Document text truncated after 10 Bytes.]",
      )
      expect(encoded.first).not_to have_key(:base64)
    end

    it "logs blank text uploads and skips the upload" do
      blank_text = "  \n\n"
      upload = create_doc_upload(contents: blank_text, filename: "blank.txt")

      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["txt"],
        )

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Failed to convert .txt upload to text",
          "upload_id=#{upload.id}",
          "blank.txt",
          "blank",
        ),
      ).at_least(:once)
      expect(encoded).to be_empty
    end

    it "logs conversion failures and skips the upload" do
      upload = create_doc_upload(contents: "raw doc bytes", filename: "sample.doc")
      error = StandardError.new("converter failed")

      allow(DiscourseAi::Completions::DocToText).to receive(:convert).and_raise(error)
      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["doc"],
        )

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Failed to convert .doc upload to text",
          "upload_id=#{upload.id}",
          "sample.doc",
          "StandardError",
          "converter failed",
        ),
      )
      expect(encoded).to be_empty
    end

    it "logs blank doc conversion output and skips the upload" do
      upload = create_doc_upload(contents: "raw doc bytes", filename: "sample.doc")

      allow(DiscourseAi::Completions::DocToText).to receive(:convert).and_return("\n  \n")
      allow(Rails.logger).to receive(:warn)

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["doc"],
        )

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including(
          "Failed to convert .doc upload to text",
          "upload_id=#{upload.id}",
          "sample.doc",
          "DOC converter returned blank output",
        ),
      )
      expect(encoded).to be_empty
    end

    it "sends allowed raw PDF documents when they are within the byte limit" do
      upload = create_doc_upload(contents: "%PDF raw bytes", filename: "sample.pdf")

      encoded =
        described_class.encode(
          upload_ids: [upload.id],
          max_pixels: 1_048_576,
          allowed_kinds: %i[document],
          allowed_attachment_types: ["pdf"],
        )

      expect(encoded.length).to eq(1)
      expect(encoded.first[:kind]).to eq(:document)
      expect(encoded.first[:filename]).to eq("sample.pdf")
      expect(Base64.strict_decode64(encoded.first[:base64])).to eq("%PDF raw bytes")
    end

    it "skips raw PDF documents that exceed the byte limit" do
      upload = create_doc_upload(contents: "%PDF raw bytes", filename: "sample.pdf")

      allow(Rails.logger).to receive(:warn)

      encoded =
        stub_const(described_class, :MAX_RAW_DOCUMENT_BYTES, 4) do
          described_class.encode(
            upload_ids: [upload.id],
            max_pixels: 1_048_576,
            allowed_kinds: %i[document],
            allowed_attachment_types: ["pdf"],
          )
        end

      expect(encoded).to be_empty
      expect(Rails.logger).to have_received(:warn).with(
        a_string_including("Skipping .pdf upload", "exceeds the 4 Bytes limit"),
      )
    end
  end
end

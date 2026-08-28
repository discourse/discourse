# frozen_string_literal: true

require "zip"

RSpec.describe DiscourseAi::Completions::UploadEncoder do
  let(:gif) { plugin_file_from_fixtures("1x1.gif") }
  let(:jpg) { plugin_file_from_fixtures("1x1.jpg") }
  let(:large_jpg) { plugin_file_from_fixtures("100x100.jpg") }
  let(:webp) { plugin_file_from_fixtures("1x1.webp") }

  before { enable_current_plugin }

  MAX_PIXELS = 1_048_576

  def encode_document(upload, attachment_type)
    described_class.encode(
      upload_ids: [upload.id],
      max_pixels: MAX_PIXELS,
      allowed_kinds: %i[document],
      allowed_attachment_types: Array(attachment_type),
    )
  end

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

  def odt_content_xml(text)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content
        xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
        <office:body>
          <office:text>
            <text:p>#{text}</text:p>
          </office:text>
        </office:body>
      </office:document-content>
    XML
  end

  def ods_content_xml(sheet_name, cell_text)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content
        xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
        xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
        <office:body>
          <office:spreadsheet>
            <table:table table:name="#{sheet_name}">
              <table:table-row>
                <table:table-cell office:value-type="string"><text:p>#{cell_text}</text:p></table:table-cell>
              </table:table-row>
            </table:table>
          </office:spreadsheet>
        </office:body>
      </office:document-content>
    XML
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
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: MAX_PIXELS)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end

  it "automatically converts webp to pngs" do
    upload = UploadCreator.new(webp, "1x1.webp").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: MAX_PIXELS)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end

  it "resizes images to the configured pixel area" do
    upload = UploadCreator.new(large_jpg, "100x100.jpg").create_for(Discourse.system_user.id)

    described_class.encode(upload_ids: [upload.id], max_pixels: 2_500)

    optimized_image = upload.optimized_images.find_by(width: 50, height: 50)
    expect(optimized_image).to be_present
  end

  it "supports jpg" do
    upload = UploadCreator.new(jpg, "1x1.jpg").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: MAX_PIXELS)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/jpeg")
  end

  it "does not raise when an upload no longer exists" do
    missing_id = Upload.maximum(:id).to_i + 1

    expect(described_class.encode(upload_ids: [missing_id], max_pixels: MAX_PIXELS)).to be_empty
  end

  describe ".doc, .docx, .xls, and .xlsx uploads" do
    before { SiteSetting.authorized_extensions = "*" }

    it "converts .doc files to text" do
      upload = create_doc_upload(contents: "raw doc bytes", filename: "sample.doc")

      allow(DiscourseAi::Completions::DocToText).to receive(:convert).and_return(
        "Converted document text\n",
      )

      encoded = encode_document(upload, ["doc"])

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

      encoded = encode_document(upload, ["doc"])

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
            zipped_document_bytes(
              "docx",
              "word/document.xml" => docx_document_xml("Converted DOCX document text"),
            ),
          filename: "sample.docx",
        )

      encoded = encode_document(upload, ["docx"])

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

    it "converts .xls files to text" do
      upload = create_doc_upload(contents: "raw xls bytes", filename: "sample.xls")

      allow(DiscourseAi::Completions::XlsToText).to receive(:convert).and_return(
        "Name,Value\nAlice,1\n",
      )

      encoded = encode_document(upload, ["xls"])

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

      encoded = encode_document(upload, ["xls"])

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
          contents: zipped_document_bytes("xlsx", "xl/worksheets/sheet1.xml" => <<~XML),
                <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                  <sheetData>
                    <row><c t="inlineStr"><is><t>Converted XLSX spreadsheet text</t></is></c></row>
                  </sheetData>
                </worksheet>
              XML
          filename: "sample.xlsx",
        )

      encoded = encode_document(upload, ["xlsx"])

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

    it "converts .odt files to text" do
      upload =
        create_doc_upload(
          contents:
            zipped_document_bytes(
              "odt",
              "content.xml" => odt_content_xml("Converted ODT document text"),
            ),
          filename: "sample.odt",
        )

      encoded = encode_document(upload, ["odt"])

      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.odt",
        mime_type: "text/plain",
        converted_from: "odt",
      )
      expect(encoded.first[:text]).to start_with("Uploaded document: sample.odt (")
      expect(encoded.first[:text]).to include("\n\nConverted ODT document text")
      expect(encoded.first).not_to have_key(:base64)
    end

    it "converts .ods files to text" do
      upload =
        create_doc_upload(
          contents:
            zipped_document_bytes(
              "ods",
              "content.xml" => ods_content_xml("Sales", "Converted ODS cell"),
            ),
          filename: "sample.ods",
        )

      encoded = encode_document(upload, ["ods"])

      expect(encoded.length).to eq(1)
      expect(encoded.first).to include(
        kind: :document,
        filename: "sample.ods",
        mime_type: "text/plain",
        converted_from: "ods",
      )
      expect(encoded.first[:text]).to start_with("Uploaded document: sample.ods (")
      expect(encoded.first[:text]).to include("\n\nSheet: Sales\n\nConverted ODS cell")
      expect(encoded.first).not_to have_key(:base64)
    end

    %w[docx xlsx odt ods].each do |extension|
      it "logs #{extension} conversion failures and skips the upload" do
        upload =
          create_doc_upload(contents: "raw #{extension} bytes", filename: "sample.#{extension}")

        allow(Rails.logger).to receive(:warn)

        encoded = encode_document(upload, [extension])

        expect(Rails.logger).to have_received(:warn).with(
          a_string_including(
            "Failed to convert .#{extension} upload to text",
            "upload_id=#{upload.id}",
            "sample.#{extension}",
            "Zip",
          ),
        )
        expect(encoded).to be_empty
      end
    end

    it "converts .rtf files to text" do
      upload =
        create_doc_upload(
          contents: "{\\rtf1\\ansi RTF {\\b document}\\par text}",
          filename: "sample.rtf",
        )

      encoded = encode_document(upload, ["rtf"])

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
          max_pixels: MAX_PIXELS,
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
          max_pixels: MAX_PIXELS,
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
        stub_const(DiscourseAi::Completions::DocumentEncoder, :MAX_TEXT_FILE_BYTES, 10) do
          encode_document(upload, ["txt"])
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

      encoded = encode_document(upload, ["txt"])

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

      encoded = encode_document(upload, ["doc"])

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

      encoded = encode_document(upload, ["doc"])

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

      encoded = encode_document(upload, ["pdf"])

      expect(encoded.length).to eq(1)
      expect(encoded.first[:kind]).to eq(:document)
      expect(encoded.first[:filename]).to eq("sample.pdf")
      expect(Base64.strict_decode64(encoded.first[:base64])).to eq("%PDF raw bytes")
    end

    it "skips raw PDF documents that exceed the byte limit" do
      upload = create_doc_upload(contents: "%PDF raw bytes", filename: "sample.pdf")

      allow(Rails.logger).to receive(:warn)

      encoded =
        stub_const(DiscourseAi::Completions::DocumentEncoder, :MAX_RAW_DOCUMENT_BYTES, 4) do
          encode_document(upload, ["pdf"])
        end

      expect(encoded).to be_empty
      expect(Rails.logger).to have_received(:warn).with(
        a_string_including("Skipping .pdf upload", "exceeds the 4 Bytes limit"),
      )
    end
  end
end

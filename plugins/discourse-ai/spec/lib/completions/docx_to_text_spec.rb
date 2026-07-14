# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::DocxToText do
  def with_docx(entries)
    tempfile = Tempfile.new(%w[document .docx])
    path = tempfile.path
    tempfile.close
    FileUtils.rm_f(path)

    ::Zip::File.open(path, create: true) do |zip_file|
      entries.each do |name, content|
        zip_file.get_output_stream(name) { |stream| stream.write(content) }
      end
    end

    yield path
  ensure
    tempfile&.close
    FileUtils.rm_f(path) if path
  end

  def word_xml(body)
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        #{body}
      </w:document>
    XML
  end

  def numbered_paragraph(text, num_id:, ilvl: 0)
    <<~XML
      <w:p>
        <w:pPr>
          <w:numPr>
            <w:ilvl w:val="#{ilvl}"/>
            <w:numId w:val="#{num_id}"/>
          </w:numPr>
        </w:pPr>
        <w:r><w:t>#{text}</w:t></w:r>
      </w:p>
    XML
  end

  def numbering_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:abstractNum w:abstractNumId="1">
          <w:lvl w:ilvl="0">
            <w:start w:val="1"/>
            <w:numFmt w:val="decimal"/>
            <w:lvlText w:val="%1."/>
          </w:lvl>
          <w:lvl w:ilvl="1">
            <w:start w:val="1"/>
            <w:numFmt w:val="lowerLetter"/>
            <w:lvlText w:val="%2)"/>
          </w:lvl>
        </w:abstractNum>
        <w:num w:numId="7">
          <w:abstractNumId w:val="1"/>
        </w:num>
        <w:abstractNum w:abstractNumId="2">
          <w:lvl w:ilvl="0">
            <w:numFmt w:val="bullet"/>
            <w:lvlText w:val="•"/>
          </w:lvl>
        </w:abstractNum>
        <w:num w:numId="8">
          <w:abstractNumId w:val="2"/>
        </w:num>
      </w:numbering>
    XML
  end

  it "extracts paragraph text from the main document" do
    with_docx("word/document.xml" => word_xml(<<~XML)) do |path|
          <w:body>
            <w:p>
              <w:r><w:t>Hello</w:t></w:r>
              <w:r><w:tab/></w:r>
              <w:r><w:t>world</w:t></w:r>
              <w:r><w:br/></w:r>
              <w:r><w:t>with a break</w:t></w:r>
            </w:p>
            <w:p><w:r><w:t>Second paragraph</w:t></w:r></w:p>
          </w:body>
        XML
      expect(described_class.convert(path)).to eq("Hello\tworld\nwith a break\nSecond paragraph")
    end
  end

  it "extracts supported text parts in a stable order" do
    part = ->(text) { word_xml("<w:p><w:r><w:t>#{text}</w:t></w:r></w:p>") }

    with_docx(
      "word/footer1.xml" => part.call("Footer"),
      "word/header2.xml" => part.call("Header two"),
      "word/document.xml" => part.call("Body"),
      "word/comments.xml" => part.call("Comment"),
      "word/header1.xml" => part.call("Header one"),
      "word/endnotes.xml" => part.call("Endnote"),
      "word/footnotes.xml" => part.call("Footnote"),
    ) do |path|
      expect(described_class.convert(path)).to eq(
        "Body\n\nHeader one\n\nHeader two\n\nFooter\n\nFootnote\n\nEndnote\n\nComment",
      )
    end
  end

  it "extracts image alt text inline" do
    with_docx("word/document.xml" => word_xml(<<~XML)) do |path|
          <w:body>
            <w:p>
              <w:r><w:t>See </w:t></w:r>
              <w:r>
                <w:drawing>
                  <wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
                    <wp:docPr id="1" name="Picture 1" descr="a diagram of the upload flow" title="Upload flow"/>
                  </wp:inline>
                </w:drawing>
              </w:r>
              <w:r><w:t> for details</w:t></w:r>
            </w:p>
          </w:body>
        XML
      expect(described_class.convert(path)).to eq(
        "See [Image: a diagram of the upload flow - Upload flow] for details",
      )
    end
  end

  it "adds prefixes for numbered and bulleted lists" do
    with_docx(
      "word/numbering.xml" => numbering_xml,
      "word/document.xml" => word_xml(<<~XML),
          <w:body>
            #{numbered_paragraph("First", num_id: 7)}
            #{numbered_paragraph("Second", num_id: 7)}
            #{numbered_paragraph("Nested", num_id: 7, ilvl: 1)}
            #{numbered_paragraph("Third", num_id: 7)}
            #{numbered_paragraph("Bullet", num_id: 8)}
          </w:body>
        XML
    ) do |path|
      expect(described_class.convert(path)).to eq(
        "1. First\n2. Second\n  a) Nested\n3. Third\n• Bullet",
      )
    end
  end

  it "returns blank text when the docx has no supported text parts" do
    with_docx("docProps/core.xml" => "<properties />") do |path|
      expect(described_class.convert(path)).to eq("")
    end
  end
end

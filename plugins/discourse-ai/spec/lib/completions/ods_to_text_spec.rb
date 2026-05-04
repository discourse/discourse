# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::OdsToText do
  def with_ods(entries)
    tempfile = Tempfile.new(%w[spreadsheet .ods])
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

  def ods_content(body)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content
        xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
        xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
        <office:body>
          <office:spreadsheet>
            #{body}
          </office:spreadsheet>
        </office:body>
      </office:document-content>
    XML
  end

  it "extracts cells from each named sheet" do
    with_ods("content.xml" => ods_content(<<~XML)) do |path|
          <table:table table:name="Summary">
            <table:table-row>
              <table:table-cell office:value-type="string"><text:p>Name</text:p></table:table-cell>
              <table:table-cell office:value-type="string"><text:p>Value</text:p></table:table-cell>
            </table:table-row>
            <table:table-row>
              <table:table-cell office:value-type="string"><text:p>Alice</text:p></table:table-cell>
              <table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell>
            </table:table-row>
          </table:table>
          <table:table table:name="Notes">
            <table:table-row>
              <table:table-cell office:value-type="string"><text:p>hello</text:p></table:table-cell>
            </table:table-row>
          </table:table>
        XML
      expect(described_class.convert(path)).to eq(
        "Sheet: Summary\n\nName\tValue\nAlice\t1\n\nSheet: Notes\n\nhello",
      )
    end
  end

  it "uses Sheet1, Sheet2 ... when no name is set" do
    with_ods("content.xml" => ods_content(<<~XML)) do |path|
          <table:table>
            <table:table-row>
              <table:table-cell office:value-type="string"><text:p>only</text:p></table:table-cell>
            </table:table-row>
          </table:table>
        XML
      expect(described_class.convert(path)).to eq("Sheet: Sheet1\n\nonly")
    end
  end

  it "renders typed values when no inline paragraph is present" do
    with_ods("content.xml" => ods_content(<<~XML)) do |path|
          <table:table table:name="Types">
            <table:table-row>
              <table:table-cell office:value-type="boolean" office:boolean-value="true"/>
              <table:table-cell office:value-type="date" office:date-value="2026-05-04"/>
              <table:table-cell office:value-type="float" office:value="42"/>
            </table:table-row>
          </table:table>
        XML
      expect(described_class.convert(path)).to eq("Sheet: Types\n\nTRUE\t2026-05-04\t42")
    end
  end

  it "expands a non-empty number-columns-repeated up to MAX_COLUMNS" do
    with_ods("content.xml" => ods_content(<<~XML)) do |path|
          <table:table table:name="Repeats">
            <table:table-row>
              <table:table-cell office:value-type="string" table:number-columns-repeated="3">
                <text:p>x</text:p>
              </table:table-cell>
              <table:table-cell office:value-type="string"><text:p>y</text:p></table:table-cell>
            </table:table-row>
          </table:table>
        XML
      expect(described_class.convert(path)).to eq("Sheet: Repeats\n\nx\tx\tx\ty")
    end
  end

  it "ignores covered (merge-continuation) cells and trims trailing empties" do
    with_ods("content.xml" => ods_content(<<~XML)) do |path|
          <table:table table:name="Merge">
            <table:table-row>
              <table:table-cell office:value-type="string"><text:p>head</text:p></table:table-cell>
              <table:covered-table-cell/>
              <table:table-cell/>
            </table:table-row>
          </table:table>
        XML
      expect(described_class.convert(path)).to eq("Sheet: Merge\n\nhead")
    end
  end

  it "returns blank text when content.xml is missing" do
    with_ods("META-INF/manifest.xml" => "<manifest/>") do |path|
      expect(described_class.convert(path)).to eq("")
    end
  end
end

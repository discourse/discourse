# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::XlsxToText do
  def with_xlsx(entries)
    tempfile = Tempfile.new(%w[workbook .xlsx])
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

  def workbook_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
          <sheet name="People" sheetId="1" r:id="rId1"/>
          <sheet name="Summary" sheetId="2" r:id="rId2"/>
        </sheets>
      </workbook>
    XML
  end

  def workbook_rels_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
      </Relationships>
    XML
  end

  def shared_strings_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="4" uniqueCount="4">
        <si><t>Name</t></si>
        <si><t>Alice</t></si>
        <si><r><t>Rich</t></r><r><t> text</t></r></si>
        <si><t>Total</t></si>
      </sst>
    XML
  end

  it "extracts sheets in workbook order as tab-delimited text" do
    with_xlsx(
      "xl/workbook.xml" => workbook_xml,
      "xl/_rels/workbook.xml.rels" => workbook_rels_xml,
      "xl/sharedStrings.xml" => shared_strings_xml,
      "xl/worksheets/sheet1.xml" => <<~XML,
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1"><v>Age</v></c></row>
            <row r="2"><c r="A2" t="s"><v>1</v></c><c r="C2" t="inlineStr"><is><t>Engineer</t></is></c></row>
            <row r="3"><c r="A3" t="s"><v>2</v></c><c r="B3" t="b"><v>1</v></c></row>
          </sheetData>
        </worksheet>
      XML
      "xl/worksheets/sheet2.xml" => <<~XML,
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1"><c r="A1" t="s"><v>3</v></c><c r="B1"><v>42</v></c></row>
          </sheetData>
        </worksheet>
      XML
    ) do |path|
      expect(described_class.convert(path)).to eq(
        "Sheet: People\n\nName\tAge\nAlice\t\tEngineer\nRich text\tTRUE\n\nSheet: Summary\n\nTotal\t42",
      )
    end
  end

  it "falls back to worksheet entries when workbook metadata is missing" do
    with_xlsx("xl/worksheets/sheet2.xml" => <<~XML, "xl/worksheets/sheet1.xml" => <<~XML) do |path|
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData><row><c t="inlineStr"><is><t>Second</t></is></c></row></sheetData>
        </worksheet>
      XML
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData><row><c t="inlineStr"><is><t>First</t></is></c></row></sheetData>
        </worksheet>
      XML
      expect(described_class.convert(path)).to eq(
        "Sheet: Sheet1\n\nFirst\n\nSheet: Sheet2\n\nSecond",
      )
    end
  end

  it "limits very wide sparse rows" do
    with_xlsx("xl/worksheets/sheet1.xml" => <<~XML) do |path|
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row><c r="A1" t="inlineStr"><is><t>Visible</t></is></c><c r="ZZ1" t="inlineStr"><is><t>Too far away</t></is></c></row>
          </sheetData>
        </worksheet>
      XML
      expect(described_class.convert(path)).to eq("Sheet: Sheet1\n\nVisible")
    end
  end

  it "returns blank text when the workbook has no readable sheets" do
    with_xlsx("docProps/core.xml" => "<properties />") do |path|
      expect(described_class.convert(path)).to eq("")
    end
  end
end

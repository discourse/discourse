# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::OdtToText do
  def with_odt(entries)
    tempfile = Tempfile.new(%w[document .odt])
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

  def odt_content(body)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content
        xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
        xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
        xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0">
        <office:body>
          <office:text>
            #{body}
          </office:text>
        </office:body>
      </office:document-content>
    XML
  end

  it "extracts headings, paragraphs, tabs, line breaks, and spans" do
    with_odt("content.xml" => odt_content(<<~XML)) do |path|
          <text:h text:outline-level="1">Title</text:h>
          <text:p>Hello<text:tab/>world<text:line-break/>second line</text:p>
          <text:p>Run with <text:span>nested <text:span>span</text:span></text:span> text</text:p>
        XML
      expect(described_class.convert(path)).to eq(
        "Title\nHello\tworld\nsecond line\nRun with nested span text",
      )
    end
  end

  it "expands repeated spaces from text:s c=N" do
    with_odt("content.xml" => odt_content(<<~XML)) do |path|
          <text:p>A<text:s text:c="3"/>B</text:p>
        XML
      expect(described_class.convert(path)).to eq("A   B")
    end
  end

  it "renders nested lists with depth-aware bullet prefixes" do
    with_odt("content.xml" => odt_content(<<~XML)) do |path|
          <text:list>
            <text:list-item><text:p>One</text:p></text:list-item>
            <text:list-item>
              <text:p>Two</text:p>
              <text:list>
                <text:list-item><text:p>Two.a</text:p></text:list-item>
                <text:list-item><text:p>Two.b</text:p></text:list-item>
              </text:list>
            </text:list-item>
            <text:list-item><text:p>Three</text:p></text:list-item>
          </text:list>
        XML
      expect(described_class.convert(path)).to eq("- One\n- Two\n  - Two.a\n  - Two.b\n- Three")
    end
  end

  it "renders tables as tab-separated rows" do
    with_odt("content.xml" => odt_content(<<~XML)) do |path|
          <table:table>
            <table:table-row>
              <table:table-cell><text:p>Name</text:p></table:table-cell>
              <table:table-cell><text:p>Value</text:p></table:table-cell>
            </table:table-row>
            <table:table-row>
              <table:table-cell><text:p>Alice</text:p></table:table-cell>
              <table:table-cell><text:p>1</text:p></table:table-cell>
            </table:table-row>
          </table:table>
        XML
      expect(described_class.convert(path)).to eq("Name\tValue\nAlice\t1")
    end
  end

  it "walks into frames and text-boxes for callout text" do
    with_odt("content.xml" => odt_content(<<~XML)) do |path|
          <text:p>Body before</text:p>
          <draw:frame>
            <draw:text-box>
              <text:p>Callout</text:p>
            </draw:text-box>
          </draw:frame>
          <text:p>Body after</text:p>
        XML
      expect(described_class.convert(path)).to eq("Body before\nCallout\nBody after")
    end
  end

  it "returns blank text when content.xml is missing" do
    with_odt("META-INF/manifest.xml" => "<manifest/>") do |path|
      expect(described_class.convert(path)).to eq("")
    end
  end
end

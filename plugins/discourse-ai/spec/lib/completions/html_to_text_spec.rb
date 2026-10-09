# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::HtmlToText do
  before { enable_current_plugin }

  def convert(contents)
    with_document_file("html", contents) { |path| described_class.convert(path) }
  end

  it "converts structure to markdown" do
    text =
      convert("<html><body><h2>Title</h2><p>A <i>word</i>.</p><ul><li>x</li></ul></body></html>")

    expect(text).to include("## Title")
    expect(text).to include("A *word*.")
    expect(text).to include("x")
  end

  it "drops scripts and styles" do
    text =
      convert("<html><body><script>alert(1)</script><style>b{}</style><p>kept</p></body></html>")

    expect(text).to eq("kept")
  end

  it "preserves multi-byte characters" do
    expect(convert("<html><body><p>café ünïcode 日本語</p></body></html>")).to include(
      "café ünïcode 日本語",
    )
  end

  it "survives invalid byte sequences" do
    expect(convert("<html><body><p>caf\xFF\xFEe</p></body></html>")).to include("caf")
  end

  it "returns an empty string for an empty document" do
    expect(convert("")).to eq("")
  end

  it "caps the extracted text" do
    stub_const(DiscourseAi::Completions::TextNormalization, :MAX_EXTRACTED_TEXT_CHARS, 10) do
      expect(convert("<html><body><p>#{"a" * 200}</p></body></html>").length).to eq(10)
    end
  end
end

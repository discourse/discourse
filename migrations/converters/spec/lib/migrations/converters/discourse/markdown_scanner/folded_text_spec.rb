# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::FoldedText do
  def span_for(folded, needle)
    index = folded.text.byteindex(needle)
    raise "#{needle.inspect} not in #{folded.text.inspect}" if index.nil?

    folded.raw_span(index, needle.bytesize)
  end

  describe ".fold" do
    it "downcases" do
      expect(described_class.fold("@Bob")).to eq("@bob")
      expect(described_class.fold(":MYEMOJI:")).to eq(":myemoji:")
    end

    it "composes, so a decomposed spelling folds to the name it denotes" do
      expect(described_class.fold("#Café")).to eq(described_class.fold("#café"))
    end
  end

  describe "an ASCII body" do
    it "folds to the same byte offsets" do
      folded = described_class.new("Hi @Bob and `@bob`")

      expect(folded.text).to eq("hi @bob and `@bob`")
      expect(span_for(folded, "@bob")).to eq([3, 4])
      expect(folded.raw_span(13, 4)).to eq([13, 4])
    end
  end

  describe "a body with multibyte characters" do
    it "maps a folded span back to the raw bytes it came from" do
      raw = "ping @CAFÉ_team now"
      folded = described_class.new(raw)

      offset, length = span_for(folded, "@café_team")
      expect(raw.byteslice(offset, length)).to eq("@CAFÉ_team")
    end

    it "maps a composed folded span back to its decomposed raw spelling" do
      decomposed = "café"
      raw = "tagged ##{decomposed} here"
      folded = described_class.new(raw)

      offset, length = span_for(folded, "#café")
      expect(raw.byteslice(offset, length)).to eq("##{decomposed}")
      # The raw spelling is one byte longer than the composed name it folds to.
      expect(length).to eq(7)
    end

    it "maps a span past a cluster that folds shorter" do
      # The Kelvin sign downcases to a plain `k`, so every folded byte after it
      # sits at a different offset than in the raw.
      raw = "K @bob"
      folded = described_class.new(raw)

      offset, length = span_for(folded, "@bob")
      expect(raw.byteslice(offset, length)).to eq("@bob")
    end

    it "denotes no raw span for a span that starts or ends inside a cluster" do
      folded = described_class.new("é@bob")

      # The second byte of the folded `é` is not a cluster of its own.
      expect(folded.raw_span(1, 1)).to be_nil
      expect(folded.raw_span(0, 1)).to be_nil
      expect(folded.raw_span(0, 2)).to eq([0, 2])
    end

    it "keeps a grapheme cluster of several codepoints together" do
      family = "👨‍👩‍👦"
      folded = described_class.new("#{family}@bob")

      offset, length = folded.raw_span(family.bytesize, 4)
      expect(offset).to eq(family.bytesize)
      expect(length).to eq(4)
      expect(folded.raw_span(1, 4)).to be_nil
    end
  end
end

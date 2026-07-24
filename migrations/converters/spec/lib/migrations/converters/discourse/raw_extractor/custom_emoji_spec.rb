# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "custom emoji" do
    subject(:extractor) { described_class.new(embeds: buffer, custom_emoji_names: %w[parrot +1]) }

    it "defers a shortcode that names a source custom emoji" do
      result = extract("nice :parrot: work")

      expect(buffer.emojis.size).to eq(1)
      emoji = buffer.emojis.first
      expect(emoji[:name]).to eq("parrot")
      expect(result).to eq("nice #{emoji[:placeholder]} work")
    end

    it "leaves a standard emoji shortcode as plain text" do
      raw = "hello :smile: there"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "does not treat a clock time as an emoji" do
      raw = "meet at 10:30:45 sharp"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "does not treat a shortcode glued to a word as an emoji" do
      raw = "path:parrot: here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    # Core's emoji boundary (`isValidEmojiPrecedingChar`) is narrower than a plain
    # "not a word character" one: it counts only tab/space (markdown-it `isSpace`),
    # a Unicode punctuation/symbol (`isPunctChar`), and a zero-width space. The
    # cases below are verified against PrettyText in `emoji_parity_spec.rb`; kept
    # here as fixtures so the fast suite pins each one.
    [
      ["no-break space", "a :parrot: b"],
      ["ideographic space", "a　:parrot: b"],
      ["superscript two", "²:parrot: b"],
      ["vulgar half", "½:parrot: b"],
      ["soft hyphen", "a­:parrot: b"],
      ["escaping backslash", "a\\:parrot: b"],
    ].each do |label, raw|
      it "leaves a shortcode after a #{label} literal, like core" do
        expect(extract(raw)).to eq(raw)
        expect(buffer.emojis).to be_empty
      end
    end

    it "defers a shortcode after a zero-width space, like core" do
      extract("a​:parrot: b")

      expect(buffer.emojis.first[:name]).to eq("parrot")
    end

    it "defers a shortcode at the start of a line, like core" do
      result = extract("first line\n:parrot: still here")

      expect(buffer.emojis.first[:name]).to eq("parrot")
      expect(result).to include("first line\n#{buffer.emojis.first[:placeholder]} still here")
    end

    it "defers a shortcode right after an opening paren" do
      extract("(:parrot:)")

      expect(buffer.emojis.first[:name]).to eq("parrot")
    end

    it "defers every shortcode of an adjacent chain" do
      result = extract("well done :parrot::+1:")

      expect(buffer.emojis.map { |emoji| emoji[:name] }).to eq(%w[parrot +1])
      placeholders = buffer.emojis.map { |emoji| emoji[:placeholder] }
      expect(result).to eq("well done #{placeholders.join}")
    end

    it "defers a custom emoji chained onto a standard one" do
      result = extract("thanks :smile::parrot:")

      expect(buffer.emojis.map { |emoji| emoji[:name] }).to eq(%w[parrot])
      expect(result).to eq("thanks :smile:#{buffer.emojis.first[:placeholder]}")
    end

    it "does not extract a custom emoji inside a fenced code block" do
      raw = <<~MD
        real :parrot:

        ```
        code :parrot: here
        ```
      MD

      result = extract(raw)

      expect(buffer.emojis.size).to eq(1)
      expect(result).to include("code :parrot: here")
    end

    it "skips emoji detection entirely when the source has no custom emoji" do
      plain_extractor = described_class.new(embeds: buffer)
      raw = "a :parrot: and :smile:"

      expect(plain_extractor.extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "leaves a toned shortcode literal even when a custom emoji shadows the name" do
      # `:parrot:t4:` cooks as the toned standard emoji when one exists — a tone
      # suffix never resolves to a custom emoji — so the text must stay as written.
      raw = "wave :parrot:t4: here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "defers the custom emoji when the tone-like text has no closing colon" do
      result = extract("wave :parrot:t4 here")

      expect(buffer.emojis.first[:name]).to eq("parrot")
      expect(result).to eq("wave #{buffer.emojis.first[:placeholder]}t4 here")
    end
  end
end

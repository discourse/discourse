# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "mentions" do
    it "defers a mention, recording the username and preserving surrounding text" do
      result = extract("hey @alice, welcome")

      expect(buffer.mentions.size).to eq(1)
      mention = buffer.mentions.first
      expect(mention).to include(mention_type: mention_type::USER, name: "alice")
      expect(result).to eq("hey #{mention[:placeholder]}, welcome")
    end

    it "defers a mention at the very start of the body" do
      result = extract("@bob hi")

      expect(buffer.mentions.first[:name]).to eq("bob")
      expect(result).to eq("#{buffer.mentions.first[:placeholder]} hi")
    end

    it "does not treat an e-mail address as a mention" do
      raw = "email me at bob@example.com please"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "captures a username containing a dot" do
      result = extract("hi @john.doe there")

      expect(buffer.mentions.first[:name]).to eq("john.doe")
      expect(result).to eq("hi #{buffer.mentions.first[:placeholder]} there")
    end

    it "keeps a trailing sentence period out of the name" do
      result = extract("thanks @bob.")

      expect(buffer.mentions.first[:name]).to eq("bob")
      expect(result).to eq("thanks #{buffer.mentions.first[:placeholder]}.")
    end

    it "captures a username with a hyphen" do
      extract("cc @some-user please")

      expect(buffer.mentions.first[:name]).to eq("some-user")
    end

    # Boundary parity with core, verified against PrettyText (the exhaustive battery
    # lives in the `:rails` mentions_parity_spec). The engine that applies core's
    # mentions rule opens a mention only when the characters on both sides of the
    # whole `@name` are whitespace or a punctuation/symbol character.
    it "opens a mention after a punctuation character such as `_`" do
      extract("a_@alice x")

      expect(buffer.mentions.first[:name]).to eq("alice")
    end

    it "treats a preceding backslash as an escape and skips the mention" do
      raw = "say \\@alice now"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "rejects a trailing character that is neither whitespace nor punctuation" do
      # `²` (superscript two) is category No — not a word character, so the name
      # ends before it, but not a boundary either, so core leaves `@alice²` literal.
      raw = "hi @alice² there"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "classifies mention types via the injected classifier" do
      classifier =
        Migrations::Converters::Discourse::MentionClassifier.new(
          here_mention: "here",
          group_names: %w[admins],
        )
      extractor = described_class.new(embeds: buffer, mention_classifier: classifier)

      extractor.extract("@gerhard @admins @here all there")

      expect(buffer.mentions.map { |m| [m[:name], m[:mention_type]] }).to eq(
        [
          ["gerhard", mention_type::USER],
          ["admins", mention_type::GROUP],
          ["here", mention_type::HERE],
        ],
      )
    end
  end

  describe "mentions with an existence gate" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
        mention_names:
          Migrations::SortedStringSet.new(
            %w[alice bob john.doe staff here all café_team].map do |name|
              Migrations::NameNormalizer.normalize(name)
            end,
          ),
      )
    end

    it "defers a mention whose username is in the set" do
      result = extract("hey @alice there")

      expect(buffer.mentions.first[:name]).to eq("alice")
      expect(result).to eq("hey #{buffer.mentions.first[:placeholder]} there")
    end

    it "leaves an @word that names nothing on the source as literal text" do
      raw = "meet at @3pm please"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "defers a group mention in the set" do
      extract("cc @staff now")

      expect(buffer.mentions.first[:name]).to eq("staff")
    end

    it "defers the here and all names in the set" do
      extract("@here and @all please")

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[here all])
    end

    it "matches the set case-insensitively" do
      extract("ping @Bob today")

      expect(buffer.mentions.first[:name]).to eq("Bob")
    end

    it "matches a Unicode name in the set" do
      extract("cc @café_team here")

      expect(buffer.mentions.first[:name]).to eq("café_team")
    end

    it "defers a dotted username in the set" do
      extract("hi @john.doe there")

      expect(buffer.mentions.first[:name]).to eq("john.doe")
    end

    it "defers every parsed @word when no gate is given" do
      ungated = described_class.new(embeds: buffer)
      ungated.extract("meet at @3pm please")

      expect(buffer.mentions.first[:name]).to eq("3pm")
    end
  end
end

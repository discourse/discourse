# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "mentions" do
    it "defers a mention, recording the username and preserving surrounding text" do
      result = extract("hey @alice, welcome")

      expect(buffer.mentions.size).to eq(1)
      mention = buffer.mentions.first
      expect(mention).to include(mention_type: enums::MentionType::USER, name: "alice")
      expect(result).to eq("hey #{mention[:placeholder]}, welcome")
    end

    context "with a name ending in a capital sigma" do
      # JavaScript folds a word-final Σ to ς and Ruby to σ; the engine reports
      # the mention verbatim, but the gate and the counter fold it and must not
      # miss the spelling the engine's own fold produces.
      let(:mention_names) do
        Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("Οδυσσευς")])
      end

      it "extracts the mention whatever case the author wrote it in" do
        result = extract("hey @ΟΔΥΣΣΕΥΣ and `@ΟΔΥΣΣΕΥΣ`")

        expect(buffer.mentions.size).to eq(1)
        expect(buffer.mentions.first[:name]).to eq("ΟΔΥΣΣΕΥΣ")
        expect(result).to eq("hey #{buffer.mentions.first[:placeholder]} and `@ΟΔΥΣΣΕΥΣ`")
      end
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

    it "defers a mention after an escaping backslash, which core cooks too" do
      # markdown-it strips the escape before the mentions rule runs, so
      # `\\@alice` is a mention on both sides of the migration; the backslash
      # stays where the author put it.
      result = extract("say \\@alice now")

      expect(buffer.mentions.first[:name]).to eq("alice")
      expect(result).to eq("say \\#{buffer.mentions.first[:placeholder]} now")
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
      extractor =
        described_class.new(
          embeds: buffer,
          markdown_engine:,
          mention_names:,
          hashtag_names:,
          mention_classifier: classifier,
        )

      extractor.extract("@gerhard @admins @here all there")

      expect(buffer.mentions.map { |m| [m[:name], m[:mention_type]] }).to eq(
        [
          ["gerhard", enums::MentionType::USER],
          ["admins", enums::MentionType::GROUP],
          ["here", enums::MentionType::HERE],
        ],
      )
    end

    it "records a broadcast mention's name as written, with its verbatim source" do
      # The importer restores that spelling whenever the destination gives it
      # no different here-mention name to remap to.
      classifier = Migrations::Converters::Discourse::MentionClassifier.new(here_mention: "here")
      extractor =
        described_class.new(
          embeds: buffer,
          markdown_engine:,
          mention_names:,
          hashtag_names:,
          mention_classifier: classifier,
        )

      extractor.extract("cc @Here and @ALL")

      expect(
        buffer.mentions.map { |m| m.values_at(:name, :mention_type, :original_markdown) },
      ).to eq(
        [["Here", enums::MentionType::HERE, "@Here"], ["ALL", enums::MentionType::ALL, "@ALL"]],
      )
    end
  end

  describe "the mention name gate" do
    let(:mention_names) do
      Migrations::CompactStringSet.new(
        %w[alice bob john.doe staff here all café_team].map do |name|
          Migrations::NameNormalizer.normalize(name)
        end,
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

    it "requires the names, so no caller can defer every @word by accident" do
      expect { described_class.new(embeds: buffer) }.to raise_error(ArgumentError, /mention_names/)
    end
  end
end

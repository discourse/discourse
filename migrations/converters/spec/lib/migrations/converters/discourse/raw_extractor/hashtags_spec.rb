# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "hashtags" do
    it "defers a bare hashtag, recording the name and leaving the type for import" do
      result = extract("see #announcements please")

      expect(buffer.hashtags.size).to eq(1)
      hashtag = buffer.hashtags.first
      expect(hashtag).to include(name: "announcements", hashtag_type: nil, target_id: nil)
      expect(result).to eq("see #{hashtag[:placeholder]} please")
    end

    it "keeps a category's parent:child separator in the name" do
      extract("in #support:billing here")

      expect(buffer.hashtags.first).to include(name: "support:billing", hashtag_type: nil)
    end

    it "records a forced ::tag suffix as the tag type, dropping the suffix from the name" do
      extract("tagged #release::tag today")

      expect(buffer.hashtags.first).to include(name: "release", hashtag_type: hashtag_type::TAG)
    end

    it "records a forced ::category suffix case-insensitively" do
      extract("filed #Support::CATEGORY now")

      expect(buffer.hashtags.first).to include(
        name: "Support",
        hashtag_type: hashtag_type::CATEGORY,
      )
    end

    it "defers a hashtag right after an opening paren" do
      result = extract("(#news)")

      expect(buffer.hashtags.first[:name]).to eq("news")
      expect(result).to eq("(#{buffer.hashtags.first[:placeholder]})")
    end

    it "defers a hashtag right after prose punctuation" do
      ["a comma,#news", 'a quote "#news"', "end of sentence.#news"].each do |raw|
        buffer.clear
        extract(raw)
        expect(buffer.hashtags.first).to include(name: "news"), "expected #{raw.inspect} to extract"
      end
    end

    it "treats a symbol before the hash as a boundary, the way core does" do
      # markdown-it's `isPunctChar` accepts Unicode symbols too, so core renders a
      # hashtag after `€` — extraction has to match.
      extract("price€#news")

      expect(buffer.hashtags.first).to include(name: "news")
    end

    it "keeps a trailing sentence dot outside the name" do
      result = extract("see #news.")

      expect(buffer.hashtags.first[:name]).to eq("news")
      expect(result).to eq("see #{buffer.hashtags.first[:placeholder]}.")
    end

    it "does not treat a markdown heading as a hashtag" do
      raw = "# Heading\n\nbody"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "does not treat a mid-word # as a hashtag" do
      raw = "issue no#42 was closed"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "leaves an unknown ::channel-style suffix as literal text" do
      raw = "chat in #general::channel today"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "does not extract a hashtag inside a fenced code block" do
      raw = <<~MD
        real #announcements

        ```
        not a #hashtag here
        ```
      MD

      result = extract(raw)

      expect(buffer.hashtags.map { |h| h[:name] }).to eq(%w[announcements])
      expect(result).to include("not a #hashtag here")
    end
  end

  describe "hashtags with an existence gate" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
        hashtag_names: Migrations::SortedStringSet.new(%w[announcements support:billing]),
      )
    end

    it "defers a hashtag whose name is in the set" do
      result = extract("see #announcements please")

      expect(buffer.hashtags.first[:name]).to eq("announcements")
      expect(result).to eq("see #{buffer.hashtags.first[:placeholder]} please")
    end

    it "leaves a hashtag that names nothing on the source as literal text" do
      raw = "tracked in PR #123 and channel #general"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "defers a parent:child category path in the set" do
      extract("filed under #support:billing today")

      expect(buffer.hashtags.first[:name]).to eq("support:billing")
    end

    it "matches the set case- and Unicode-insensitively" do
      extract("see #Announcements please")

      expect(buffer.hashtags.first[:name]).to eq("Announcements")
    end

    it "leaves a forced suffix on an unknown name as literal text" do
      raw = "tagged #unknown::tag today"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "gates a forced suffix on the name, deferring a known one" do
      extract("in #announcements::category now")

      expect(buffer.hashtags.first).to include(
        name: "announcements",
        hashtag_type: hashtag_type::CATEGORY,
      )
    end

    it "matches a dotted name whole instead of stopping at the dot" do
      dotted =
        described_class.new(
          embeds: buffer,
          hashtag_names: Migrations::SortedStringSet.new(%w[v2.0]),
        )
      dotted.extract("ship #v2.0 today")

      expect(buffer.hashtags.first[:name]).to eq("v2.0")
    end

    it "does not truncate a dotted name to a shorter prefix that is in the set" do
      dotted =
        described_class.new(embeds: buffer, hashtag_names: Migrations::SortedStringSet.new(%w[v2]))
      raw = "ship #v2.0 today"

      expect(dotted.extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end
  end
end

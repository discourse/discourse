# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  subject(:extractor) { described_class.new }

  let(:buffer) do
    Migrations::Converters::EmbedBuffer.new(
      owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
    )
  end

  def extract(raw)
    extractor.extract(raw, on_embed: buffer)
  end

  it "returns nil for a nil body" do
    expect(extract(nil)).to be_nil
  end

  it "leaves a body with no embeds untouched" do
    raw = "Just some **plain** text with a (paren) and a / slash."

    expect(extract(raw)).to eq(raw)
    expect(buffer).to be_empty
  end

  describe "uploads" do
    it "defers an image upload, recording the sha1" do
      result = extract("before ![alt|690x388](upload://abc123XYZ.png) after")

      expect(buffer.uploads.size).to eq(1)
      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq("abc123XYZ")
      expect(result).to eq("before #{upload[:placeholder]} after")
    end

    it "defers an attachment upload" do
      extract("[report.pdf|attachment](upload://Zm9vYmFy.pdf)")

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
    end
  end

  describe "quotes" do
    it "defers the attribution and preserves the quoted body and closing tag" do
      result = extract(%([quote="bob, post:12, topic:5"]\nquoted body\n[/quote]))

      expect(buffer.quotes.size).to eq(1)
      quote = buffer.quotes.first
      expect(quote[:quoted_username]).to eq("bob")
      expect(quote[:quoted_post_id]).to eq("12")
      expect(result).to eq("#{quote[:placeholder]}\nquoted body\n[/quote]")
    end

    it "uses the explicit username: attribute when a display name is present" do
      extract(%([quote="Bob Jones, post:1, topic:2, username:bjones"]hi[/quote]))

      expect(buffer.quotes.first[:quoted_username]).to eq("bjones")
      expect(buffer.quotes.first[:quoted_post_id]).to eq("1")
    end

    it "defers a username-only quote" do
      extract(%([quote="alice"]hello[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "alice", quoted_post_id: nil)
    end

    it "leaves an unattributed quote alone" do
      raw = "[quote]anonymous[/quote]"

      expect(extract(raw)).to eq(raw)
      expect(buffer.quotes).to be_empty
    end
  end

  describe "mentions" do
    it "defers a mention, recording the username and preserving surrounding text" do
      result = extract("hey @alice, welcome")

      expect(buffer.mentions.size).to eq(1)
      mention = buffer.mentions.first
      expect(mention).to include(mention_type: "user", name: "alice")
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

    it "classifies mention types via the injected resolver" do
      resolver =
        Migrations::Converters::Discourse::MentionResolver.new(
          here_mention: "here",
          group_names: %w[admins],
        )
      extractor = described_class.new(mention_resolver: resolver)

      extractor.extract("@gerhard @admins @here all there", on_embed: buffer)

      expect(buffer.mentions.map { |m| [m[:name], m[:mention_type]] }).to eq(
        [%w[gerhard user], %w[admins group], %w[here here]],
      )
    end
  end

  # The whole reason to wrap Markbridge's scanner: things that only look like
  # embeds inside code must be left alone.
  describe "code blocks" do
    it "does not extract from a fenced code block" do
      raw = <<~MD
        real @alice here

        ```
        not a @mention and ![x](upload://nope.png) and [quote="ghost"]q[/quote]
        ```
      MD

      result = extract(raw)

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
      expect(buffer.uploads).to be_empty
      expect(buffer.quotes).to be_empty
      expect(result).to include("not a @mention and ![x](upload://nope.png)")
    end

    it "does not extract from inline code" do
      result = extract("use `@channel` carefully, @alice")

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
      expect(result).to include("`@channel`")
    end
  end

  # The contract: every token spliced into the result maps to exactly one recorded
  # linkage descriptor.
  it "keeps placeholders and linkage rows one-to-one" do
    result =
      extract(
        "intro @carol see ![pic](upload://h45h.png) and " \
          "[quote=\"dan, post:9, topic:3\"]q[/quote] done",
      )

    expect(Migrations::Placeholder.scan(result)).to match_array(buffer.placeholders)
  end

  describe "Unicode raw" do
    it "leaves a body of only Unicode text untouched" do
      raw = "これは 🎉 café テスト — nothing to extract"

      expect(extract(raw)).to eq(raw)
      expect(buffer).to be_empty
    end

    it "captures a whole Unicode username, not just its ASCII prefix" do
      extract("cc @café_team here")

      expect(buffer.mentions.first[:name]).to eq("café_team")
    end

    it "captures a username with a combining mark (decomposed form)" do
      name = "José".unicode_normalize(:nfd)
      extract("ping @#{name} thanks")

      captured = buffer.mentions.first[:name]
      expect(captured.unicode_normalize).to eq("José".unicode_normalize)
    end

    it "captures a CJK username" do
      extract("hi @田中 there")

      expect(buffer.mentions.first[:name]).to eq("田中")
    end

    it "does not treat @name after a Unicode letter as a mention" do
      raw = "café@john"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "preserves Unicode around an extracted embed and stays valid encoding" do
      result = extract("日本語 ![絵](upload://abc.png) 🎉")

      expect(buffer.uploads.size).to eq(1)
      expect(result).to eq("日本語 #{buffer.uploads.first[:placeholder]} 🎉")
      expect(result).to be_valid_encoding
    end

    it "does not extract embeds from a code block that contains Unicode" do
      raw = "```\n@josé [quote=\"x, post:1\"] 日本\n```\n@real"
      result = extract(raw)

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[real])
      expect(result).to include("@josé", '[quote="x, post:1"]', "日本")
    end
  end
end

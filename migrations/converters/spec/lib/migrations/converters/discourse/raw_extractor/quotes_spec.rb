# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "quotes" do
    it "records the source coordinates as integers and never a post_id" do
      result = extract(%([quote="bob, post:12, topic:5"]\nquoted body\n[/quote]))

      expect(buffer.quotes.size).to eq(1)
      quote = buffer.quotes.first
      expect(quote).to include(
        quoted_username: "bob",
        quoted_topic_id: 5,
        quoted_post_number: 12,
        quoted_post_id: nil,
      )
      expect(result).to eq("#{quote[:placeholder]}\nquoted body\n[/quote]")
    end

    it "uses the explicit username: part and keeps the display name" do
      extract(%([quote="Bob Jones, post:1, topic:2, username:bjones"]\nhi\n[/quote]))

      expect(buffer.quotes.first).to include(
        quoted_username: "bjones",
        quoted_name: "Bob Jones",
        quoted_topic_id: 2,
        quoted_post_number: 1,
      )
    end

    it "records no name for a bare leading token that IS the username" do
      # Without an explicit username:, the leading token is the username itself
      # (Discourse omits username: when the display name equals it).
      extract(%([quote="jane, post:1"]\nhi\n[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "jane", quoted_name: nil)
    end

    it "records no name when the display name equals the explicit username" do
      extract(%([quote="jane, post:1, topic:2, username:jane"]\nhi\n[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "jane", quoted_name: nil)
    end

    it "fills the containing topic id when the header names a post but no topic" do
      extract(%([quote="bob, post:12"]\nbody\n[/quote]), topic_id: 77)

      expect(buffer.quotes.first).to include(quoted_topic_id: 77, quoted_post_number: 12)
    end

    it "records no coordinates for a username-only quote" do
      extract(%([quote="alice"]\nhello\n[/quote]), topic_id: 77)

      expect(buffer.quotes.first).to include(
        quoted_username: "alice",
        quoted_topic_id: nil,
        quoted_post_number: nil,
        quoted_post_id: nil,
      )
    end

    it "reads an unquoted header, with and without parts" do
      extract(%([quote=alice]\nhello\n[/quote]))
      expect(buffer.quotes.first).to include(quoted_username: "alice")

      extract(%([quote=bob, post:3, topic:4]\nhi\n[/quote]))
      expect(buffer.quotes.last).to include(
        quoted_username: "bob",
        quoted_post_number: 3,
        quoted_topic_id: 4,
      )
    end

    it "strips a single-quoted, curly or guillemet-wrapped header down to the name" do
      {
        %([quote='alice']\nx\n[/quote]) => "alice",
        %([quote=“alice”]\nx\n[/quote]) => "alice",
        %([quote=«alice»]\nx\n[/quote]) => "alice",
        %([quote=‘alice’]\nx\n[/quote]) => "alice",
      }.each do |raw, username|
        buffer.quotes.clear
        extract(raw)
        expect(buffer.quotes.first).to include(quoted_username: username)
      end
    end

    it "keeps a mismatched or one-sided quote mark as part of the header" do
      # Core strips only a matching pair; anything else stays a literal character,
      # so the header (and the username we read from it) keeps the mark. Verified
      # against PrettyText.
      {
        %([quote="bob']\nx\n[/quote]) => %("bob'),
        %([quote=bob"]\nx\n[/quote]) => %(bob"),
        %([quote=""]\nx\n[/quote]) => %(""),
      }.each do |raw, username|
        buffer.quotes.clear
        extract(raw)
        expect(buffer.quotes.first).to include(quoted_username: username)
      end
    end

    it "extracts when only spaces or tabs follow the opening tag" do
      extract(%([quote="bob"]  \t \nx\n[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "bob")
    end

    it "leaves the tag literal when non-space text follows it on the line" do
      # Core only renders the block when nothing but spaces/tabs follow the opening
      # tag to the end of its line, so text after the tag makes it plain BBCode.
      raw = %([quote="bob"] and then some\nx\n[/quote])

      expect(extract(raw)).to eq(raw)
      expect(buffer.quotes).to be_empty
    end

    it "leaves a quote with no header alone" do
      raw = "[quote]anonymous[/quote]"

      expect(extract(raw)).to eq(raw)
      expect(buffer.quotes).to be_empty
    end
  end
end

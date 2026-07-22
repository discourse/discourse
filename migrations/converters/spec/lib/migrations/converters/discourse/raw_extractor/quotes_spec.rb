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
      extract(%([quote="Bob Jones, post:1, topic:2, username:bjones"]hi[/quote]))

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
      extract(%([quote="jane, post:1"]hi[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "jane", quoted_name: nil)
    end

    it "records no name when the display name equals the explicit username" do
      extract(%([quote="jane, post:1, topic:2, username:jane"]hi[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "jane", quoted_name: nil)
    end

    it "fills the containing topic id when the header names a post but no topic" do
      extract(%([quote="bob, post:12"]body[/quote]), topic_id: 77)

      expect(buffer.quotes.first).to include(quoted_topic_id: 77, quoted_post_number: 12)
    end

    it "records no coordinates for a username-only quote" do
      extract(%([quote="alice"]hello[/quote]), topic_id: 77)

      expect(buffer.quotes.first).to include(
        quoted_username: "alice",
        quoted_topic_id: nil,
        quoted_post_number: nil,
        quoted_post_id: nil,
      )
    end

    it "leaves a quote with no header alone" do
      raw = "[quote]anonymous[/quote]"

      expect(extract(raw)).to eq(raw)
      expect(buffer.quotes).to be_empty
    end
  end
end

# frozen_string_literal: true

RSpec.describe Migrations::Converters::EmbedBuffer do
  subject(:buffer) { described_class.new }

  describe "recording embeds" do
    it "records a quote descriptor keyed for IntermediateDB::PostQuote" do
      token = buffer.quote(quoted_post_id: 1, quoted_user_id: 2, quoted_username: "bob")

      expect(buffer.quotes).to contain_exactly(
        { placeholder: token, quoted_post_id: 1, quoted_user_id: 2, quoted_username: "bob" },
      )
    end

    it "records a link descriptor keyed for IntermediateDB::PostLink" do
      token = buffer.link(url: "https://example.com", text: "here", target_topic_id: 9)

      expect(buffer.links).to contain_exactly(
        {
          placeholder: token,
          url: "https://example.com",
          text: "here",
          target_topic_id: 9,
          target_post_id: nil,
        },
      )
    end

    it "records a mention descriptor keyed for IntermediateDB::PostMention" do
      token = buffer.mention(mention_type: "user", target_id: 7, name: "bob")

      expect(buffer.mentions).to contain_exactly(
        { placeholder: token, mention_type: "user", target_id: 7, name: "bob" },
      )
    end

    it "accepts every known mention type, plus nil" do
      types = [*Migrations::MentionType::TYPES, nil]

      expect { types.each { |type| buffer.mention(mention_type: type) } }.not_to raise_error
    end

    it "rejects an unknown mention type so a typo fails loud" do
      expect { buffer.mention(mention_type: "Group") }.to raise_error(
        ArgumentError,
        /Unknown mention type/,
      )
    end

    it "records a poll descriptor keyed for IntermediateDB::PostPoll" do
      token = buffer.poll(poll_id: 3)

      expect(buffer.polls).to contain_exactly({ placeholder: token, poll_id: 3 })
    end

    it "records an event descriptor keyed for IntermediateDB::PostEvent" do
      token = buffer.event(event_id: 4)

      expect(buffer.events).to contain_exactly({ placeholder: token, event_id: 4 })
    end

    it "records an upload descriptor keyed for IntermediateDB::PostUpload" do
      token = buffer.upload(upload_id: "abc123")

      expect(buffer.uploads).to contain_exactly({ placeholder: token, upload_id: "abc123" })
    end

    it "returns the minted token so the cooker can splice it into the raw" do
      expect(buffer.quote(quoted_user_id: 1)).to eq(buffer.quotes.last[:placeholder])
    end
  end

  describe "#empty?" do
    it "is true before anything is recorded" do
      expect(buffer).to be_empty
    end

    it "is false once an embed is recorded" do
      buffer.upload(upload_id: "x")

      expect(buffer).not_to be_empty
    end
  end

  # The single invariant the whole design rests on: the token spliced into the raw
  # and the `placeholder` on the linkage row are byte-identical, one-to-one.
  describe "the placeholder contract" do
    it "mints one token per embed, each present exactly once in the cooked raw" do
      raw = +"Intro "
      raw << buffer.quote(quoted_user_id: 5)
      raw << " see "
      raw << buffer.link(url: "https://example.com", text: "x")
      raw << " hi "
      raw << buffer.mention(mention_type: "user", target_id: 7, name: "bob")
      raw << " poll "
      raw << buffer.poll(poll_id: 1)
      raw << " event "
      raw << buffer.event(event_id: 2)
      raw << " pic "
      raw << buffer.upload(upload_id: "sha1")
      raw << " end"

      tokens_in_raw = Migrations::Placeholder.scan(raw)

      # Every token in the raw has exactly one matching linkage descriptor, and
      # every descriptor's placeholder is present in the raw.
      expect(tokens_in_raw).to match_array(buffer.placeholders)
      expect(tokens_in_raw.size).to eq(buffer.placeholders.size)
      buffer.placeholders.each { |placeholder| expect(raw.scan(placeholder).size).to eq(1) }
    end

    it "never mints the same token twice" do
      tokens = Array.new(10) { buffer.upload(upload_id: "x") }

      expect(tokens.uniq.size).to eq(10)
    end
  end
end

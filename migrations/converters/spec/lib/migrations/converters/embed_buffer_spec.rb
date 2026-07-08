# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::EmbedBuffer do
  subject(:buffer) { described_class.new(owner_type:) }

  let(:hashtag_type) { Migrations::Database::IntermediateDB::Enums::HashtagType }
  let(:mention_type) { Migrations::Database::IntermediateDB::Enums::MentionType }

  let(:owner_type) { Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST }

  describe "construction" do
    it "requires an owner_type" do
      expect { described_class.new }.to raise_error(ArgumentError, /owner_type/)
    end
  end

  describe "recording embeds" do
    it "records a quote descriptor keyed for IntermediateDB::EmbedQuote" do
      token =
        buffer.quote(
          quoted_post_id: 1,
          quoted_topic_id: 8,
          quoted_post_number: 3,
          quoted_user_id: 2,
          quoted_username: "bob",
          quoted_name: "Bob B",
        )

      expect(buffer.quotes).to contain_exactly(
        {
          placeholder: token,
          quoted_post_id: 1,
          quoted_topic_id: 8,
          quoted_post_number: 3,
          quoted_user_id: 2,
          quoted_username: "bob",
          quoted_name: "Bob B",
        },
      )
    end

    it "records a link descriptor keyed for IntermediateDB::EmbedLink" do
      token =
        buffer.link(
          url: "https://example.com",
          text: "here",
          target_type: Migrations::Database::IntermediateDB::Enums::LinkTarget::TOPIC,
          target_id: 9,
        )

      expect(buffer.links).to contain_exactly(
        {
          placeholder: token,
          url: "https://example.com",
          text: "here",
          target_type: Migrations::Database::IntermediateDB::Enums::LinkTarget::TOPIC,
          target_id: 9,
          target_name: nil,
          target_topic_id: nil,
          target_post_number: nil,
          target_suffix: nil,
        },
      )
    end

    it "records a mention descriptor keyed for IntermediateDB::EmbedMention" do
      token = buffer.mention(mention_type: mention_type::USER, target_id: 7, name: "bob")

      expect(buffer.mentions).to contain_exactly(
        { placeholder: token, mention_type: mention_type::USER, target_id: 7, name: "bob" },
      )
    end

    it "accepts every known mention type, plus nil" do
      types = [*mention_type.values, nil]

      expect { types.each { |type| buffer.mention(mention_type: type) } }.not_to raise_error
    end

    it "rejects an unknown mention type so a typo fails loud" do
      expect { buffer.mention(mention_type: "Group") }.to raise_error(
        ArgumentError,
        /Unknown mention type/,
      )
    end

    it "records a hashtag descriptor keyed for IntermediateDB::EmbedHashtag" do
      token = buffer.hashtag(hashtag_type: hashtag_type::CATEGORY, target_id: nil, name: "support")

      expect(buffer.hashtags).to contain_exactly(
        {
          placeholder: token,
          hashtag_type: hashtag_type::CATEGORY,
          target_id: nil,
          name: "support",
        },
      )
    end

    it "accepts every known hashtag type, plus nil" do
      types = [*hashtag_type.values, nil]

      expect { types.each { |type| buffer.hashtag(hashtag_type: type) } }.not_to raise_error
    end

    it "rejects an unknown hashtag type so a typo fails loud" do
      expect { buffer.hashtag(hashtag_type: "Tag") }.to raise_error(
        ArgumentError,
        /Unknown hashtag type/,
      )
    end

    it "records an emoji descriptor keyed for IntermediateDB::EmbedEmoji" do
      token = buffer.emoji(name: "parrot")

      expect(buffer.emojis).to contain_exactly({ placeholder: token, name: "parrot" })
    end

    it "records a poll descriptor keyed for IntermediateDB::EmbedPoll" do
      token = buffer.poll(poll_id: 3)

      expect(buffer.polls).to contain_exactly({ placeholder: token, poll_id: 3 })
    end

    it "records an event descriptor keyed for IntermediateDB::EmbedEvent" do
      token = buffer.event(event_id: 4)

      expect(buffer.events).to contain_exactly({ placeholder: token, event_id: 4 })
    end

    it "records an upload descriptor keyed for IntermediateDB::EmbedUpload" do
      token = buffer.upload(upload_id: "abc123", original_markdown: "![x](/uploads/x.png)")

      expect(buffer.uploads).to contain_exactly(
        { placeholder: token, upload_id: "abc123", original_markdown: "![x](/uploads/x.png)" },
      )
    end

    it "returns the minted token so the Markdown converter can splice it into the raw" do
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
    it "mints one token per embed, each present exactly once in the converted raw" do
      raw = +"Intro "
      raw << buffer.quote(quoted_user_id: 5)
      raw << " see "
      raw << buffer.link(url: "https://example.com", text: "x")
      raw << " hi "
      raw << buffer.mention(mention_type: mention_type::USER, target_id: 7, name: "bob")
      raw << " tag "
      raw << buffer.hashtag(name: "support")
      raw << " emoji "
      raw << buffer.emoji(name: "parrot")
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

  # Each recorder feeds one linkage table; its descriptor must carry every column
  # that table expects (minus `owner_type`/`owner_id`, which `write_for` adds).
  # This is what guards against schema drift, since these tables are written
  # through the shared buffer and so are held out of the per-converter coverage
  # gate.
  describe "linkage column coverage" do
    idb = Migrations::Database::IntermediateDB

    {
      quote: [:quotes, idb::EmbedQuote],
      link: [:links, idb::EmbedLink],
      mention: [:mentions, idb::EmbedMention],
      hashtag: [:hashtags, idb::EmbedHashtag],
      emoji: [:emojis, idb::EmbedEmoji],
      poll: [:polls, idb::EmbedPoll],
      event: [:events, idb::EmbedEvent],
      upload: [:uploads, idb::EmbedUpload],
    }.each do |recorder, (collection, model)|
      it "records every #{model.name.split("::").last} column" do
        buffer.public_send(recorder)
        descriptor = buffer.public_send(collection).last
        columns = model.method(:create).parameters.map { |_type, name| name }

        expect(descriptor.keys + %i[owner_type owner_id]).to match_array(columns)
      end
    end
  end

  describe "#write_for" do
    around do |example|
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, "intermediate.db")
        Migrations::Database.migrate(
          db_path,
          migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
        )
        @db = Migrations::Database.connect(db_path)
        Migrations::Database::IntermediateDB.setup(@db)
        example.run
      ensure
        Migrations::Database::IntermediateDB.setup(nil)
      end
    end

    def rows(table)
      [].tap { |out| @db.query("SELECT * FROM #{table}") { |row| out << row } }
    end

    it "inserts each recorded embed into its linkage table under the owner" do
      quote = buffer.quote(quoted_user_id: 5)
      mention = buffer.mention(mention_type: mention_type::USER, target_id: 7)
      hashtag = buffer.hashtag(name: "support:billing")
      emoji = buffer.emoji(name: "parrot")
      upload = buffer.upload(upload_id: "sha1")

      buffer.write_for(42)

      expect(rows("embed_quotes")).to contain_exactly(
        hash_including(owner_type:, owner_id: 42, placeholder: quote, quoted_user_id: 5),
      )
      expect(rows("embed_mentions")).to contain_exactly(
        hash_including(
          owner_type:,
          owner_id: 42,
          placeholder: mention,
          mention_type: mention_type::USER,
          target_id: 7,
        ),
      )
      expect(rows("embed_hashtags")).to contain_exactly(
        hash_including(
          owner_type:,
          owner_id: 42,
          placeholder: hashtag,
          name: "support:billing",
          hashtag_type: nil,
        ),
      )
      expect(rows("embed_emojis")).to contain_exactly(
        hash_including(owner_type:, owner_id: 42, placeholder: emoji, name: "parrot"),
      )
      expect(rows("embed_uploads")).to contain_exactly(
        hash_including(owner_type:, owner_id: 42, placeholder: upload, upload_id: "sha1"),
      )
    end

    it "writes the owner_type bound at construction" do
      user_type = Migrations::Database::IntermediateDB::Enums::EmbedOwner::USER
      user_buffer = described_class.new(owner_type: user_type)
      user_buffer.upload(upload_id: "sha1")

      user_buffer.write_for(7)

      expect(rows("embed_uploads")).to contain_exactly(
        hash_including(owner_type: user_type, owner_id: 7),
      )
    end

    it "writes nothing for an empty buffer" do
      buffer.write_for(42)

      expect(rows("embed_quotes")).to be_empty
    end
  end

  describe "#clear" do
    it "empties every collection so the buffer can be reused" do
      buffer.upload(upload_id: "a")
      buffer.mention(name: "bob")

      buffer.clear

      expect(buffer).to be_empty
      expect(buffer.uploads).to be_empty
      expect(buffer.mentions).to be_empty
    end

    it "keeps minting unique tokens after a clear (the sequence does not reset)" do
      first = buffer.upload(upload_id: "a")
      buffer.clear
      second = buffer.upload(upload_id: "b")

      expect(second).not_to eq(first)
    end
  end
end

# frozen_string_literal: true

module Migrations
  module Converters
    # Collects the embeds found while an owner's body is converted to Markdown.
    #
    # The owner is any markdown-bearing record — a post body today, a user bio,
    # group/category/badge descriptions later. Its kind is fixed at construction
    # (`owner_type`), so one buffer serves one kind of owner.
    #
    # For each embed it can't finish yet (a quote, link, mention, poll, event or
    # upload), the Markdown converter calls the matching recorder here. We can't
    # render the embed now because that needs the import maps, which only exist at
    # import time. So the buffer mints a token, stores a descriptor that carries it,
    # and returns the token to put into the raw in place of the embed.
    #
    # After the body is converted, the owning step writes the owner and then calls
    # `write_for(owner_id)`, which inserts every recorded embed into its linkage
    # table. A descriptor's keys match the table columns (minus `owner_type`/`owner_id`).
    #
    # Recording embeds is pure (no database, no maps), so building a buffer is safe
    # on the converter's worker threads. `write_for` is the only part that writes.
    class EmbedBuffer
      IntermediateDB = Migrations::Database::IntermediateDB
      private_constant :IntermediateDB

      attr_reader :quotes, :links, :mentions, :polls, :events, :uploads

      # @param owner_type [Integer] the owning record's kind, an
      #   `IntermediateDB::Enums::EmbedOwner` value (e.g. `EmbedOwner::POST`).
      # @param placeholder [Migrations::Placeholder] the token source; by default a
      #   fresh one (with its own nonce) per buffer.
      def initialize(owner_type:, placeholder: Migrations::Placeholder.new)
        @owner_type = owner_type
        @placeholder = placeholder
        @quotes = []
        @links = []
        @mentions = []
        @polls = []
        @events = []
        @uploads = []
      end

      # The token replaces the opening `[quote="..."]` tag only. The Markdown
      # converter writes the quoted text, the closing `[/quote]`, and the blank lines
      # around them into the raw as plain text; none of that goes into the row.
      #
      # @return [String] the token for the opening tag.
      def quote(
        quoted_post_id: nil,
        quoted_topic_id: nil,
        quoted_post_number: nil,
        quoted_user_id: nil,
        quoted_username: nil,
        quoted_name: nil
      )
        record(
          @quotes,
          :quote,
          quoted_post_id:,
          quoted_topic_id:,
          quoted_post_number:,
          quoted_user_id:,
          quoted_username:,
          quoted_name:,
        )
      end

      def link(url: nil, text: nil, target_type: nil, target_id: nil)
        record(@links, :link, url:, text:, target_type:, target_id:)
      end

      # @raise [ArgumentError] if `mention_type` is not nil or a known type.
      def mention(mention_type: nil, target_id: nil, name: nil)
        validate_mention_type!(mention_type)
        record(@mentions, :mention, mention_type:, target_id:, name:)
      end

      def poll(poll_id: nil)
        record(@polls, :poll, poll_id:)
      end

      def event(event_id: nil)
        record(@events, :event, event_id:)
      end

      # `original_markdown` is the verbatim source snippet for an upload referenced
      # by a full URL, so the importer can put it back when the sha1 maps to no
      # Discourse upload. It stays nil for a short `upload://` reference, which has
      # no meaningful fallback.
      def upload(upload_id: nil, original_markdown: nil)
        record(@uploads, :upload, upload_id:, original_markdown:)
      end

      # Empties the recorded embeds (in place, keeping the collections) so one buffer
      # can be reused for the next owner instead of allocating a fresh one — and its
      # placeholder along with it — per owner. The placeholder is kept: its running
      # sequence is what keeps tokens unique across the owners that share the buffer.
      def clear
        @quotes.clear
        @links.clear
        @mentions.clear
        @polls.clear
        @events.clear
        @uploads.clear
        self
      end

      # Inserts each recorded embed into its linkage table. Call once per owner, after
      # the owner row is written.
      def write_for(owner_id)
        owner_type = @owner_type
        @quotes.each { |row| IntermediateDB::EmbedQuote.create(owner_type:, owner_id:, **row) }
        @links.each { |row| IntermediateDB::EmbedLink.create(owner_type:, owner_id:, **row) }
        @mentions.each { |row| IntermediateDB::EmbedMention.create(owner_type:, owner_id:, **row) }
        @polls.each { |row| IntermediateDB::EmbedPoll.create(owner_type:, owner_id:, **row) }
        @events.each { |row| IntermediateDB::EmbedEvent.create(owner_type:, owner_id:, **row) }
        @uploads.each { |row| IntermediateDB::EmbedUpload.create(owner_type:, owner_id:, **row) }
      end

      # @return [Array<String>] every token created, in order (used to assert they
      #   all reached the raw).
      def placeholders
        descriptors.map { |descriptor| descriptor[:placeholder] }
      end

      # @return [Boolean] whether the post had no embeds.
      def empty?
        descriptors.empty?
      end

      private

      def descriptors
        @quotes + @links + @mentions + @polls + @events + @uploads
      end

      def record(collection, kind, **fields)
        placeholder = @placeholder.mint(kind)
        collection << { placeholder:, **fields }
        placeholder
      end

      def validate_mention_type!(type)
        return if type.nil? || Migrations::MentionType::TYPES.include?(type)

        raise ArgumentError,
              "Unknown mention type #{type.inspect}; expected nil or one of #{Migrations::MentionType::TYPES.join(", ")}"
      end
    end
  end
end

# frozen_string_literal: true

module Migrations
  module Converters
    # Collects the embeds found while a post body is converted to Markdown.
    #
    # For each embed the Markdown converter can't finish yet (a quote, link, mention, poll,
    # event or upload) it calls the matching recorder here (#quote, #link, and so
    # on). The embed can't be rendered now because that needs the import maps, which
    # only exist at import time. So the buffer creates a token (via Placeholder),
    # stores a descriptor that carries it, and returns the token for the Markdown converter to
    # put into the raw in place of the embed.
    #
    # After the body is converted, the Posts step writes the post and then calls
    # `write_for(post_id)`, which inserts every recorded embed into its linkage
    # table. A descriptor's keys match the table columns (minus `post_id`), so it
    # passes straight into `create`.
    #
    # Recording embeds is pure (no database, no maps), so building a buffer is safe
    # on the converter's worker threads. `write_for` is the only part that writes,
    # through the same `IntermediateDB` models every other converter step uses.
    class EmbedBuffer
      IntermediateDB = Migrations::Database::IntermediateDB
      private_constant :IntermediateDB

      attr_reader :quotes, :links, :mentions, :polls, :events, :uploads

      # @param placeholder [Migrations::Placeholder] the token source; by default a
      #   fresh one (with its own nonce) per buffer.
      def initialize(placeholder: Migrations::Placeholder.new)
        @placeholder = placeholder
        @quotes = []
        @links = []
        @mentions = []
        @polls = []
        @events = []
        @uploads = []
      end

      # Records what's needed to build a quote's opening `[quote="..."]` tag. The
      # token replaces that tag only. The Markdown converter writes the quoted text, the closing
      # `[/quote]`, and the blank lines around them into the raw as plain text; none
      # of that needs resolving or goes into the linkage table.
      #
      # @return [String] the token for the opening tag.
      def quote(quoted_post_id: nil, quoted_user_id: nil, quoted_username: nil)
        record(@quotes, :quote, quoted_post_id:, quoted_user_id:, quoted_username:)
      end

      def link(url: nil, text: nil, target_topic_id: nil, target_post_id: nil)
        record(@links, :link, url:, text:, target_topic_id:, target_post_id:)
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

      def upload(upload_id: nil)
        record(@uploads, :upload, upload_id:)
      end

      # Writes every recorded embed to its IntermediateDB linkage table under
      # `post_id`. Call once per post, after the post itself is written.
      def write_for(post_id)
        @quotes.each { |row| IntermediateDB::PostQuote.create(post_id:, **row) }
        @links.each { |row| IntermediateDB::PostLink.create(post_id:, **row) }
        @mentions.each { |row| IntermediateDB::PostMention.create(post_id:, **row) }
        @polls.each { |row| IntermediateDB::PostPoll.create(post_id:, **row) }
        @events.each { |row| IntermediateDB::PostEvent.create(post_id:, **row) }
        @uploads.each { |row| IntermediateDB::PostUpload.create(post_id:, **row) }
      end

      # Every token this buffer has created, in order. Useful for checking that each
      # one ended up in the converted raw.
      #
      # @return [Array<String>]
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

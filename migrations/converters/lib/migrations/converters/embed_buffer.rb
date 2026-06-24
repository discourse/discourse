# frozen_string_literal: true

module Migrations
  module Converters
    # Collects the embeds found while a post body is converted to Markdown.
    #
    # For each embed the cooker can't finish yet (a quote, link, mention, poll,
    # event or upload) it calls the matching recorder here (#quote, #link, and so
    # on). The embed can't be rendered now because that needs the import maps, which
    # only exist at import time. So the buffer creates a token (via Placeholder),
    # stores a descriptor that carries it, and returns the token for the cooker to
    # put into the raw in place of the embed.
    #
    # After the body is converted, the Posts step writes the post and copies each
    # descriptor into its linkage table, e.g.
    #
    #     buffer.quotes.each { |q| IntermediateDB::PostQuote.create(post_id:, **q) }
    #
    # A descriptor's keys match the linkage table columns (minus `post_id`), so it
    # passes straight into `create`. The buffer touches no database and no maps,
    # which keeps it safe to run on the converter's worker threads.
    class EmbedBuffer
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
      # token replaces that tag only. The cooker writes the quoted text, the closing
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

      # Every token this buffer has created, in order. Useful for checking that each
      # one ended up in the cooked raw.
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

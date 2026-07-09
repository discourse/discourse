# frozen_string_literal: true

module Migrations
  module Converters
    # Collects the embeds found while an owner's body is converted to Markdown.
    #
    # The owner is the record the markdown belongs to — a post today, a user bio
    # or a group/category/badge description later. Its kind is fixed at
    # construction (`owner_type`), so one buffer serves one kind of owner.
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

      attr_reader :quotes, :links, :mentions, :hashtags, :emojis, :polls, :events, :uploads

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
        @hashtags = []
        @emojis = []
        @polls = []
        @events = []
        @uploads = []
      end

      # The token replaces the opening `[quote="..."]` tag only. The Markdown
      # converter writes the quoted text, the closing `[/quote]`, and the blank lines
      # around them into the raw as plain text; none of that goes into the row.
      #
      # The quoted post is identified either by id or by coordinates, whichever the
      # source gives — the importer resolves the coordinates to a post before
      # rendering (post numbers are recomputed at import).
      #
      # @param quoted_post_id [Integer, String, nil] the quoted post's source
      #   `original_id`, when the converter knows it.
      # @param quoted_topic_id [Integer, String, nil] with `quoted_post_number`, the
      #   source coordinates the attribution carries — the alternative to
      #   `quoted_post_id`.
      # @param quoted_post_number [Integer, nil] see `quoted_topic_id`.
      # @param quoted_user_id [Integer, String, nil] the quoted user's source
      #   `original_id`.
      # @param quoted_username [String, nil] the attribution's display fallback, used
      #   when the quoted user can't be mapped to a Discourse user; when
      #   `quoted_user_id` is nil, the importer also resolves it to the user.
      # @param quoted_name [String, nil] like `quoted_username`, for sources that
      #   attribute quotes by full name.
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

      # The target is identified in one of three forms, and only one is set per
      # call: by id (`target_id`), by name (`target_name`), or by coordinates
      # (`target_topic_id` + `target_post_number`). All stay nil for an external
      # link, which is just text carried through.
      #
      # @param url [String, nil] the full source URL; the fallback whenever the
      #   target can't be resolved.
      # @param text [String, nil] a markdown link's link text; nil for a bare URL,
      #   which is re-emitted bare to keep oneboxes working.
      # @param target_type [Integer, nil] the kind of Discourse entity the link
      #   points at, an `IntermediateDB::Enums::LinkTarget` value (e.g.
      #   `LinkTarget::TOPIC`); nil for an external link.
      # @param target_id [Integer, String, nil] the target's source `original_id` —
      #   for a topic, post, category or badge addressed by id in the URL.
      # @param target_name [String, nil] the target's name — a username, group name,
      #   tag name, or a category slug path written `parent:child` — when the URL
      #   carries a name but no id.
      # @param target_topic_id [Integer, String, nil] with `target_post_number`, the
      #   source coordinates of a post addressed as `/t/slug/<topic_id>/<post_number>`;
      #   post numbers are recomputed at import, so the importer resolves them.
      # @param target_post_number [Integer, nil] see `target_topic_id`.
      # @param target_suffix [String, nil] everything after the matched route
      #   (further path, query string, fragment), reattached verbatim when the URL
      #   is rebuilt.
      def link(
        url: nil,
        text: nil,
        target_type: nil,
        target_id: nil,
        target_name: nil,
        target_topic_id: nil,
        target_post_number: nil,
        target_suffix: nil
      )
        record(
          @links,
          :link,
          url:,
          text:,
          target_type:,
          target_id:,
          target_name:,
          target_topic_id:,
          target_post_number:,
          target_suffix:,
        )
      end

      # @param mention_type [Integer, nil] an `IntermediateDB::Enums::MentionType`
      #   value (user, group, here or all).
      # @param target_id [Integer, String, nil] the mentioned user's or group's
      #   source `original_id`; nil for `here`/`all`.
      # @param name [String, nil] the mention as written, without the leading `@`.
      # @raise [ArgumentError] if `mention_type` is neither nil nor a known type.
      def mention(mention_type: nil, target_id: nil, name: nil)
        validate_mention_type!(mention_type)
        record(@mentions, :mention, mention_type:, target_id:, name:)
      end

      # @param hashtag_type [Integer, nil] an `IntermediateDB::Enums::HashtagType`
      #   value (category or tag). Set it when the source forced the type with a
      #   `::tag`/`::category` suffix or when `target_id` is given (an id renders
      #   only through its type); otherwise nil, and the importer classifies the
      #   name (categories first, then tags).
      # @param target_id [Integer, String, nil] the source `original_id` of the
      #   category or tag, for a converter that identifies the target instead of
      #   just naming it; the importer then skips name resolution. Pin
      #   `hashtag_type` along with it.
      # @param name [String, nil] the hashtag as written, without the leading `#`
      #   and any `::tag`/`::category` suffix; may hold one `:` as the
      #   `parent:child` category separator. Required even when `target_id` is
      #   set — it's the fallback text when the target can't be mapped at import.
      # @raise [ArgumentError] if `hashtag_type` is neither nil nor a known type.
      def hashtag(hashtag_type: nil, target_id: nil, name: nil)
        validate_hashtag_type!(hashtag_type)
        record(@hashtags, :hashtag, hashtag_type:, target_id:, name:)
      end

      # Only the source's own custom emoji reach here; a standard shortcode stays
      # plain text.
      #
      # @param name [String, nil] the shortcode without the surrounding colons.
      def emoji(name: nil)
        record(@emojis, :emoji, name:)
      end

      # @param poll_id [Integer, String, nil] the poll's source `original_id` (a
      #   `polls` row converted by its own step); the importer renders that poll
      #   into the raw.
      def poll(poll_id: nil)
        record(@polls, :poll, poll_id:)
      end

      # @param event_id [Integer, String, nil] the event's source `original_id` (an
      #   `events` row converted by its own step); the importer renders that event
      #   into the raw.
      def event(event_id: nil)
        record(@events, :event, event_id:)
      end

      # @param upload_id [String, nil] the referenced `uploads` row's id — a content
      #   hash, so text rather than numeric.
      # @param original_markdown [String, nil] the verbatim source snippet for an
      #   upload referenced by a full URL, so the importer can put it back when the
      #   sha1 maps to no Discourse upload. Stays nil for a short `upload://`
      #   reference, which has no meaningful fallback.
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
        @hashtags.clear
        @emojis.clear
        @polls.clear
        @events.clear
        @uploads.clear
        self
      end

      # Inserts each recorded embed into its linkage table. Call once per owner, after
      # the owner row is written.
      #
      # @param owner_id [Integer, String] the owner's source `original_id`, matching
      #   the id the owner row was written with.
      def write_for(owner_id)
        owner_type = @owner_type
        @quotes.each { |row| IntermediateDB::EmbedQuote.create(owner_type:, owner_id:, **row) }
        @links.each { |row| IntermediateDB::EmbedLink.create(owner_type:, owner_id:, **row) }
        @mentions.each { |row| IntermediateDB::EmbedMention.create(owner_type:, owner_id:, **row) }
        @hashtags.each { |row| IntermediateDB::EmbedHashtag.create(owner_type:, owner_id:, **row) }
        @emojis.each { |row| IntermediateDB::EmbedEmoji.create(owner_type:, owner_id:, **row) }
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
        @quotes + @links + @mentions + @hashtags + @emojis + @polls + @events + @uploads
      end

      def record(collection, kind, **fields)
        placeholder = @placeholder.mint(kind)
        collection << { placeholder:, **fields }
        placeholder
      end

      def validate_mention_type!(type)
        return if type.nil? || IntermediateDB::Enums::MentionType.valid?(type)

        valid = IntermediateDB::Enums::MentionType.values.join(", ")
        raise ArgumentError, "Unknown mention type #{type.inspect}; expected nil or one of #{valid}"
      end

      def validate_hashtag_type!(type)
        return if type.nil? || IntermediateDB::Enums::HashtagType.valid?(type)

        valid = IntermediateDB::Enums::HashtagType.values.join(", ")
        raise ArgumentError, "Unknown hashtag type #{type.inspect}; expected nil or one of #{valid}"
      end
    end
  end
end

# frozen_string_literal: true

module Migrations
  module Converters
    # Collects the embeds found while an owner's body is converted to Markdown.
    # The owner is the record the markdown belongs to — a post today, a user bio
    # or a group/category/badge description later — and its kind is fixed at
    # construction, so one buffer serves one kind of owner.
    #
    # An embed cannot be rendered during conversion, because that needs the
    # import maps, which only exist at import time. So the converter calls the
    # matching recorder here, which mints a token, stores a descriptor carrying
    # it, and returns the token to put into the raw in place of the embed.
    # Afterwards the owning step writes the owner and calls
    # `write_for(owner_id)`. A descriptor's keys match the linkage table's
    # columns (minus `owner_type`/`owner_id`).
    #
    # Recording is pure (no database, no maps), so building a buffer is safe on
    # the converter's worker threads. `write_for` is the only part that writes.
    class EmbedBuffer
      IntermediateDB = Migrations::Database::IntermediateDB
      private_constant :IntermediateDB

      attr_reader :quotes, :links, :mentions, :hashtags, :emojis, :polls, :events, :uploads

      # @param placeholder [Migrations::Placeholder] the token source; by
      #   default a fresh one, with its own nonce, per buffer.
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

      # The token replaces the opening `[quote="..."]` tag only; the quoted text
      # and the closing `[/quote]` stay in the raw as plain text. The quoted
      # post is identified by id or by coordinates, whichever the source gives —
      # post numbers are recomputed at import, so the importer resolves a
      # coordinate pair to a post before rendering.
      #
      # @param quoted_username [String, nil] the header's display fallback; with
      #   no `quoted_user_id`, the importer also resolves it to the user.
      # @param quoted_name [String, nil] for sources that name the quoted user
      #   by full name.
      # @param original_markdown [String, nil] the verbatim source snippet,
      #   restored unchanged when the importer cannot map the embed.
      # @return [String] the token for the opening tag.
      def quote(
        quoted_post_id: nil,
        quoted_topic_id: nil,
        quoted_post_number: nil,
        quoted_user_id: nil,
        quoted_username: nil,
        quoted_name: nil,
        original_markdown: nil
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
          original_markdown:,
        )
      end

      # Exactly one addressing form is set per call: by id, by name
      # (`target_name`: a username, group name, tag name or a `parent:child`
      # category slug path), or by coordinates. All stay nil for an external
      # link, which is just text carried through.
      #
      # @param url [String, nil] the full source URL; the fallback on a miss.
      # @param text [String, nil] a markdown link's link text; nil for a bare
      #   URL, which is re-emitted bare to keep oneboxes working.
      # @param target_tag_path [String, nil] `[none/|all/]<tag>` for a
      #   `CATEGORY_TAG` link (whose category rides in
      #   `target_id`/`target_name`), `<t1>/<t2>[/…]` for a `TAG_INTERSECTION`
      #   link.
      # @param target_suffix [String, nil] everything after the matched route,
      #   reattached verbatim when the URL is rebuilt.
      # @param url_offset [Integer, nil] the destination's byte offset within
      #   `original_markdown`, its span `url.bytesize` long — the importer
      #   rewrites exactly that span rather than searching for the value.
      # @param label_url_offset [Integer, nil] the offset of a self-link label
      #   spelling the destination too; nil otherwise.
      def link(
        url: nil,
        text: nil,
        target_type: nil,
        target_id: nil,
        target_name: nil,
        target_topic_id: nil,
        target_post_number: nil,
        target_tag_path: nil,
        target_suffix: nil,
        original_markdown: nil,
        url_offset: nil,
        label_url_offset: nil
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
          target_tag_path:,
          target_suffix:,
          original_markdown:,
          url_offset:,
          label_url_offset:,
        )
      end

      # @param mention_type [Integer, nil] an `Enums::MentionType` value; nil
      #   for an unclassified mention, which the importer treats as a user
      #   mention.
      # @param name [String, nil] the mention without the leading `@`; the
      #   lookup key and the fallback text on a miss.
      # @raise [ArgumentError] on an unknown `mention_type`.
      def mention(mention_type: nil, target_id: nil, name: nil, original_markdown: nil)
        validate_mention_type!(mention_type)
        record(@mentions, :mention, mention_type:, target_id:, name:, original_markdown:)
      end

      # @param hashtag_type [Integer, nil] an `Enums::HashtagType` value. Set it
      #   when the source forced the type with a `::tag`/`::category` suffix or
      #   when `target_id` is given (an id renders only through its type);
      #   otherwise nil, and the importer classifies the name.
      # @param name [String, nil] the hashtag without the leading `#` and any
      #   `::tag`/`::category` suffix; may hold one `:` as the `parent:child`
      #   separator. Required even with `target_id` — the fallback text on a
      #   miss.
      # @raise [ArgumentError] on an unknown `hashtag_type`.
      def hashtag(hashtag_type: nil, target_id: nil, name: nil, original_markdown: nil)
        validate_hashtag_type!(hashtag_type)
        record(@hashtags, :hashtag, hashtag_type:, target_id:, name:, original_markdown:)
      end

      # No `original_markdown` snippet: an emoji embed only exists when its
      # `:name:` bytes occur in the source, so the importer rebuilds the exact
      # source spelling from the name alone.
      def emoji(name: nil)
        record(@emojis, :emoji, name:)
      end

      def poll(poll_id: nil)
        record(@polls, :poll, poll_id:)
      end

      def event(event_id: nil)
        record(@events, :event, event_id:)
      end

      # @param upload_id [String, nil] the referenced `uploads` row's id — a
      #   content hash, so text rather than numeric. The Discourse extractor
      #   records the 40-hex sha1 for full-URL forms and the base62 short id for
      #   `upload://` references, so the importer's map must answer both.
      # @param external_host [String, nil] for a full-URL upload on a host that
      #   is not the source's own: the importer maps its id only when the
      #   conversion allowlists that host, so a foreign URL whose basename
      #   collides with a source upload sha1 is restored verbatim.
      def upload(upload_id: nil, original_markdown: nil, external_host: nil)
        record(@uploads, :upload, upload_id:, original_markdown:, external_host:)
      end

      # Empties the recorded embeds in place, so one buffer can serve the next
      # owner. The placeholder is kept: its running sequence is what keeps
      # tokens unique across the owners that share a buffer.
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

      # Call once per owner, after the owner row is written. `owner_id` is the
      # owner's source `original_id`.
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

      # @return [Array<String>] every token created, in order (used to assert
      #   they all reached the raw).
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

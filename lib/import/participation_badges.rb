# frozen_string_literal: true

module Import
  class ParticipationBadges
    PARTICIPATION_BADGE_IDS = [
      Badge::FirstLike,
      Badge::FirstQuote,
      Badge::FirstLink,
      Badge::FirstMention,
      Badge::Welcome,
      Badge::NicePost,
      Badge::GoodPost,
      Badge::GreatPost,
      Badge::NiceTopic,
      Badge::GoodTopic,
      Badge::GreatTopic,
    ].freeze
    IMPORT_ID_FIELD = "import_id"
    IMPORTED_POST_SELECT = PostCustomField.where(name: IMPORT_ID_FIELD).select(:post_id)
    BATCH_SIZE = 1000

    def self.grant_all
      new.grant_all
    end

    def grant_all
      derive_quotes
      derive_mentions
      derive_links
      backfill_participation_badges
    end

    def each_imported_post_in_chronological_order(scope = Post.all, &block)
      last_created_at = Time.at(0)
      last_id = 0

      loop do
        batch =
          scope
            .where(id: IMPORTED_POST_SELECT)
            .where("(created_at, id) > (?, ?)", last_created_at, last_id)
            .order(:created_at, :id)
            .limit(BATCH_SIZE)
            .to_a

        break if batch.empty?

        batch.each { |post| block.call(post) }
        last_created_at = batch.last.created_at
        last_id = batch.last.id
      end
    end

    def derive_quotes
      log "Deriving quoted_posts from asides / reply-parent linkage..."
      count = 0

      each_imported_post_in_chronological_order(
        Post.where("cooked LIKE ?", "%aside class=\"quote%"),
      ) do |post|
        QuotedPost.where(post_id: post.id).delete_all

        targets =
          Nokogiri::HTML5
            .fragment(post.cooked)
            .css("aside.quote")
            .filter_map do |aside|
              if aside["data-topic"].present? && aside["data-post"].present?
                Post.where(
                  topic_id: aside["data-topic"].to_i,
                  post_number: aside["data-post"].to_i,
                ).pick(:id)
              elsif post.reply_to_post_number.present?
                Post.where(topic_id: post.topic_id, post_number: post.reply_to_post_number).pick(
                  :id,
                )
              end
            end
            .uniq

        targets.each do |quoted_post_id|
          next if quoted_post_id.blank? || quoted_post_id == post.id

          quoted =
            QuotedPost.find_or_initialize_by(post_id: post.id, quoted_post_id: quoted_post_id)
          if quoted.new_record?
            quoted.created_at = post.created_at
            quoted.updated_at = Time.now
            quoted.save!
            count += 1
          end
        end

        # Mirror the reply_quoted consistency QuotedPost.extract_from performs:
        # when the reply target is among the quotes, mark the post so quote-as-
        # reply tips (suppress_reply_when_quoting) don't show redundant context.
        if post.reply_to_post_number.present?
          reply_post_id =
            Post.where(topic_id: post.topic_id, post_number: post.reply_to_post_number).pick(:id)
          reply_quoted =
            reply_post_id.present? &&
              QuotedPost.where(post_id: post.id, quoted_post_id: reply_post_id).exists?
          post.update_columns(reply_quoted: reply_quoted) if reply_quoted != post.reply_quoted
        end
      end

      puts "  #{count} quoted posts derived."
    end

    def derive_mentions
      log "Deriving mention user_actions from cooked..."
      count = 0
      base = Discourse.base_path

      UserAction
        .where(action_type: UserAction::MENTION)
        .where(target_post_id: IMPORTED_POST_SELECT)
        .delete_all

      Post
        .where("cooked LIKE ?", "%class=\"mention\"%")
        .where(id: IMPORTED_POST_SELECT)
        .find_each do |post|
          Nokogiri::HTML5
            .fragment(post.cooked)
            .css("a.mention")
            .each do |anchor|
              # href <name> is percent-encoded after a possible subfolder base
              # prefix; strip the prefix and decode so it resolves to the account.
              href = anchor["href"].to_s
              path = base.present? && href.start_with?("#{base}/") ? href.delete_prefix(base) : href
              next unless path =~ %r{\A/u/([^/]+)\z}
              raw_name = Addressable::URI.unencode_component($1)
              next if raw_name.blank?

              matches = User.where(username_lower: ::User.normalize_username(raw_name)).pluck(:id)
              # An ambiguous username must not attribute the mention arbitrarily.
              next if matches.size != 1

              mentioned_id = matches.first
              next if mentioned_id == post.user_id

              UserAction.log_action!(
                action_type: UserAction::MENTION,
                user_id: mentioned_id,
                target_topic_id: post.topic_id,
                target_post_id: post.id,
                acting_user_id: post.user_id,
                created_at: post.created_at,
              )
              count += 1
            end
        end

      puts "  #{count} mention actions derived."
    end

    def derive_links
      log "Deriving topic_links from cooked (canonical TopicLink.extract_from)..."
      count = 0
      failures = []

      reconstruct_forward_links

      crawl = TopicLink.method(:crawl_link_title)
      TopicLink.define_singleton_method(:crawl_link_title) { |_id| }
      begin
        each_imported_post_in_chronological_order do |post|
          next unless post.user_id && post.cooked&.match?(/<a /)

          # extract_from owns its own cleanup_entries, which only tears down this
          # post's forward rows and its own reflections (link_post_id = post.id).
          # Reflections other posts created pointing into this post are preserved.
          TopicLink.extract_from(post)
          count += 1
        rescue StandardError => e
          failures << { post_id: post.id, error: e }
          warn "  Failed to extract links from post #{post.id}: #{e.class}: #{e.message}"
        end
      ensure
        TopicLink.define_singleton_method(:crawl_link_title, crawl)
      end

      unless failures.empty?
        raise "Topic link extraction failed for #{failures.size} post(s) " \
                "(first: #{failures.first[:error].class}: #{failures.first[:error].message}); " \
                "aborting before badge backfill"
      end

      # Rebase this import's forward-link timestamps onto their source posts' so
      # the grant date reflects chronology. Only non-reflection rows: reflections
      # set post_id to the linked-to post, so reading posts[post_id] would stamp
      # them with the wrong (target) timestamp, and they aren't read by FirstLink.
      TopicLink
        .where(post_id: IMPORTED_POST_SELECT)
        .where(reflection: false)
        .where(
          "topic_links.created_at <> (SELECT p.created_at FROM posts p WHERE p.id = topic_links.post_id)",
        )
        .update_all(
          "created_at = (SELECT p.created_at FROM posts p WHERE p.id = topic_links.post_id)",
        )

      puts "  Visited #{count} posts for topic links."
    end

    def backfill_participation_badges
      log "Backfilling participation badges..."
      with_suppressed_badge_notifications do
        Badge
          .where(id: PARTICIPATION_BADGE_IDS)
          .find_each { |badge| Jobs::BackfillBadge.new.execute(badge_id: badge.id) }
      end
    end

    private

    def reconstruct_forward_links
      candidates =
        TopicLink
          .where(post_id: IMPORTED_POST_SELECT)
          .where.not(reflection: true)
          .where(quote: false)
          .where(internal: true)
          .where.not(link_post_id: nil)
          .where("topic_id <> link_topic_id")

      TopicLinkClick.where(topic_link_id: candidates.select(:id)).delete_all
      candidates.delete_all
    end

    def with_suppressed_badge_notifications(&blk)
      stub = Object.new
      stub.define_singleton_method(:enabled?) { true }
      block = proc { |_suppressed| true }
      DiscoursePluginRegistry.register_modifier(stub, :badge_granter_suppress_notification, &block)
      # Retained so specs can unregister the hook (allowed only in test env).
      @badge_notification_suppression = [stub, block]
      blk.call
    end

    def log(message)
      puts "[#{DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}"
    end
  end
end

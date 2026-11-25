# frozen_string_literal: true

module Jobs
  class UpdateUsername < ::Jobs::Base
    sidekiq_options queue: "low"
    # this is an extremely expensive job
    # we are limiting it so only 1 per cluster runs
    cluster_concurrency 1

    NOTIFICATION_USERNAME_NAME_PAIRS = {
      original_username: :original_name,
      display_username: :display_name,
      username: :name,
      username2: :name2,
    }.freeze

    UNPAIRED_POST_AUTHOR_NOTIFICATION_TYPES = [
      Notification.types[:edited],
      Notification.types[:mentioned],
      Notification.types[:group_mentioned],
    ].freeze

    def execute(args)
      @user_id = args[:user_id]
      user = User.find_by(id: @user_id)
      return unless user

      @old_username = args[:old_username].unicode_normalize
      @new_username = args[:new_username].unicode_normalize

      @avatar_img = PrettyText.avatar_img(args[:avatar_template], "tiny")

      @quote_rewriter = QuoteRewriter.new(@user_id)

      escaped_old_username = Regexp.escape(@old_username)
      @raw_mention_regex =
        /
        (?:
          (?<![\p{Alnum}\p{M}`])     # make sure there is no preceding letter, number or backtick
        )
        @#{escaped_old_username}
        (?:
          (?![\p{Alnum}\p{M}_\-.`])  # make sure there is no trailing letter, number, underscore, dash, dot or backtick
          |                          # or
          (?=[-_.](?:\s|$))          # there is an underscore, dash or dot followed by a whitespace or end of line
        )
      /ix

      cooked_username = PrettyText::Helpers.format_username(@old_username)
      escaped_cooked_username = Regexp.escape(cooked_username)
      escaped_encoded_cooked_username = Regexp.escape(UrlHelper.encode_component(cooked_username))
      @cooked_mention_username_regex = /\A@#{escaped_cooked_username}\z/i
      @cooked_mention_user_path_regex = %r{\A/u(?:sers)?/#{escaped_encoded_cooked_username}\z}i

      update_posts
      update_revisions
      update_notifications
      update_post_custom_fields

      DiscourseEvent.trigger(:username_changed, @old_username, @new_username)
      DiscourseEvent.trigger(:user_updated, user, %w[username])
    end

    def update_posts
      updated_post_ids = Set.new

      # Other people mentioning this user
      Post
        .with_deleted
        .joins(mentioned("posts.id"))
        .where("a.user_id = :user_id", user_id: @user_id)
        .find_each do |post|
          update_post(post)
          updated_post_ids << post.id
        end

      # User mentioning self (not included in post_actions table)
      Post
        .with_deleted
        .where("raw ILIKE ?", "%@#{@old_username}%")
        .where("posts.user_id = :user_id", user_id: @user_id)
        .where.not(id: updated_post_ids)
        .find_each do |post|
          update_post(post)
          updated_post_ids << post.id
        end

      # Posts quoting this user
      Post
        .with_deleted
        .joins(quoted("posts.id"))
        .where("p.user_id = :user_id", user_id: @user_id)
        .where.not(id: updated_post_ids)
        .find_each do |post|
          update_post(post)
          updated_post_ids << post.id
        end

      # Category description posts may be authored by the system user and have no user_actions
      Post
        .with_deleted
        .joins("INNER JOIN categories ON categories.topic_id = posts.topic_id")
        .where(post_number: 1)
        .where("raw ILIKE ?", "%@#{@old_username}%")
        .where.not(id: updated_post_ids)
        .find_each { |post| update_post(post) }
    end

    def update_revisions
      PostRevision
        .where("modifications SIMILAR TO ?", "%(raw|cooked)%@#{@old_username}%")
        .find_each { |revision| update_revision(revision) }

      PostRevision
        .joins(quoted("post_revisions.post_id"))
        .where("p.user_id = :user_id", user_id: @user_id)
        .find_each { |revision| update_revision(revision) }
    end

    def update_notifications
      new_name = User.where(id: @user_id).pick(:name).presence
      params = {
        user_id: @user_id,
        old_username: @old_username,
        new_username: @new_username,
        new_name: new_name,
        collapsed_types: PostAlerter::COLLAPSED_NOTIFICATION_TYPES,
        unpaired_post_author_types: UNPAIRED_POST_AUTHOR_NOTIFICATION_TYPES,
      }

      username_updates =
        NOTIFICATION_USERNAME_NAME_PAIRS
          .keys
          .map do |k|
            "'#{k}', CASE WHEN data::JSONB ->> '#{k}' = :old_username THEN :new_username END"
          end
          .join(",\n")

      data_expr =
        if new_name
          name_updates =
            NOTIFICATION_USERNAME_NAME_PAIRS
              .map do |u_key, n_key|
                "'#{n_key}', CASE WHEN data::JSONB ? '#{n_key}' AND data::JSONB ->> '#{u_key}' = :old_username THEN :new_name END"
              end
              .join(",\n")
          "data::JSONB || jsonb_strip_nulls(jsonb_build_object(#{username_updates}, #{name_updates}))"
        else
          removals =
            NOTIFICATION_USERNAME_NAME_PAIRS
              .map do |u_key, n_key|
                "CASE WHEN data::JSONB ->> '#{u_key}' = :old_username THEN ARRAY['#{n_key}'] ELSE ARRAY[]::text[] END"
              end
              .join(" || ")
          "(data::JSONB || jsonb_strip_nulls(jsonb_build_object(#{username_updates}))) - (#{removals})"
        end

      where_clause =
        NOTIFICATION_USERNAME_NAME_PAIRS
          .keys
          .map { |k| "data::JSONB ->> '#{k}' = :old_username" }
          .join(" OR ")

      DB.exec(<<~SQL, params)
        UPDATE notifications
        SET data = (#{data_expr})::JSON
        WHERE #{where_clause}
      SQL

      # Collapsed notifications store the first unread post's author in `display_name`
      # while `display_username` holds a count string, and `edited` or editor-added
      # mention notifications can pair the editor's `display_username` with the post
      # author's `display_name`.
      post_author_data_expr =
        if new_name
          "CASE WHEN notifications.notification_type IN (:collapsed_types) " \
            "THEN notifications.data::JSONB || jsonb_build_object('display_name', :new_name) " \
            "ELSE notifications.data::JSONB - 'display_name' END"
        else
          "notifications.data::JSONB - 'display_name'"
        end

      DB.exec(<<~SQL, params)
        UPDATE notifications
        SET data = (#{post_author_data_expr})::JSON
        FROM posts p
        WHERE notifications.topic_id = p.topic_id
          AND notifications.post_number = p.post_number
          AND p.user_id = :user_id
          AND notifications.data::JSONB ? 'display_name'
          AND (
            notifications.notification_type IN (:collapsed_types)
            OR (
              notifications.notification_type IN (:unpaired_post_author_types)
              AND notifications.data::JSONB ->> 'display_username' IS DISTINCT FROM :new_username
            )
          )
      SQL
    end

    def update_post_custom_fields
      DB.exec(<<~SQL, old_username: @old_username, new_username: @new_username)
        UPDATE post_custom_fields
        SET value = :new_username
        WHERE name = 'action_code_who' AND value = :old_username
      SQL
    end

    protected

    def update_post(post)
      post.raw = update_raw(post.raw)
      post.cooked = update_cooked(post.cooked)

      post.update_columns(raw: post.raw, cooked: post.cooked)
      post.sync_first_post_caches

      SearchIndexer.index(post, force: true) if post.topic
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update post with id #{post.id}")
    end

    def update_revision(revision)
      if revision.modifications.key?("raw") || revision.modifications.key?("cooked")
        revision.modifications["raw"]&.map! { |raw| update_raw(raw) }
        revision.modifications["cooked"]&.map! { |cooked| update_cooked(cooked) }
        revision.save!
      end
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update post revision with id #{revision.id}")
    end

    def mentioned(post_id_column)
      <<~SQL
        JOIN user_actions AS a ON (a.target_post_id = #{post_id_column} AND
                                   a.action_type = #{UserAction::MENTION})
      SQL
    end

    def quoted(post_id_column)
      <<~SQL
        JOIN quoted_posts AS q ON (q.post_id = #{post_id_column})
        JOIN posts AS p ON (q.quoted_post_id = p.id)
      SQL
    end

    def update_raw(raw)
      @quote_rewriter.rewrite_raw_username(
        raw.gsub(@raw_mention_regex, "@#{@new_username}"),
        @old_username,
        @new_username,
      )
    end

    # Uses Nokogiri instead of rebake, because it works for posts and revisions
    # and there is no reason to invalidate oneboxes, run the post analyzer etc.
    # when only the username changes.
    def update_cooked(cooked)
      doc = Nokogiri::HTML5.fragment(cooked)

      doc
        .css("a.mention")
        .each do |a|
          a.content = a.content.gsub(@cooked_mention_username_regex, "@#{@new_username}")
          a["href"] = a["href"].gsub(
            @cooked_mention_user_path_regex,
            "/u/#{UrlHelper.encode_component(@new_username)}",
          ) if a["href"]
        end

      @quote_rewriter.rewrite_cooked_username(doc, @old_username, @new_username, @avatar_img)

      doc.to_html
    end
  end
end

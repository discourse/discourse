# frozen_string_literal: true

module Jobs
  class UpdateUsername < ::Jobs::Base
    sidekiq_options queue: "low"
    # this is an extremely expensive job
    # we are limiting it so only 1 per cluster runs
    cluster_concurrency 1

    def execute(args)
      @user_id = args[:user_id]
      user = User.find_by(id: @user_id)
      return unless user

      @old_username = args[:old_username].unicode_normalize
      @new_username = args[:new_username].unicode_normalize

      @avatar_img = PrettyText.avatar_img(args[:avatar_template], "tiny")

      @quote_rewriter = QuoteRewriter.new(@user_id)

      @raw_mention_regex =
        /
        (?:
          (?<![\p{Alnum}\p{M}`])     # make sure there is no preceding letter, number or backtick
        )
        @#{@old_username}
        (?:
          (?![\p{Alnum}\p{M}_\-.`])  # make sure there is no trailing letter, number, underscore, dash, dot or backtick
          |                          # or
          (?=[-_.](?:\s|$))          # there is an underscore, dash or dot followed by a whitespace or end of line
        )
      /ix

      cooked_username = PrettyText::Helpers.format_username(@old_username)
      @cooked_mention_username_regex = /\A@#{cooked_username}\z/i
      @cooked_mention_user_path_regex =
        %r{\A/u(?:sers)?/#{UrlHelper.encode_component(cooked_username)}\z}i

      update_posts
      update_revisions
      update_notifications
      update_post_custom_fields

      DiscourseEvent.trigger(:username_changed, @old_username, @new_username)
      DiscourseEvent.trigger(:user_updated, user)
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
        .find_each do |post|
          update_post(post)
          updated_post_ids << post.id
        end

      Post
        .with_deleted
        .joins(quoted("posts.id"))
        .where("p.user_id = :user_id", user_id: @user_id)
        .find_each { |post| update_post(post) if updated_post_ids.exclude?(post.id) }
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
      params = { user_id: @user_id, old_username: @old_username, new_username: @new_username }

      DB.exec(<<~SQL, params)
        UPDATE notifications
        SET data = (data :: JSONB ||
                    jsonb_strip_nulls(
                        jsonb_build_object(
                            'original_username', CASE data :: JSONB ->> 'original_username'
                                                 WHEN :old_username
                                                   THEN :new_username
                                                 ELSE NULL END,
                            'display_username', CASE data :: JSONB ->> 'display_username'
                                                WHEN :old_username
                                                  THEN :new_username
                                                ELSE NULL END,
                            'username', CASE data :: JSONB ->> 'username'
                                        WHEN :old_username
                                          THEN :new_username
                                        ELSE NULL END,
                            'username2', CASE data :: JSONB ->> 'username2'
                                        WHEN :old_username
                                          THEN :new_username
                                        ELSE NULL END
                        )
                    )) :: JSON
        WHERE
          data :: JSONB ->> 'original_username' = :old_username OR
          data :: JSONB ->> 'display_username' = :old_username OR
          data :: JSONB ->> 'username' = :old_username OR
          data :: JSONB ->> 'username2' = :old_username
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

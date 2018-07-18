module Jobs
  class UpdateUsername < Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      @user_id = args[:user_id]
      @old_username = args[:old_username]
      @new_username = args[:new_username]
      @avatar_img = PrettyText.avatar_img(args[:avatar_template], "tiny")

      @raw_mention_regex = /(?:(?<![\w`_])|(?<=_))@#{@old_username}(?:(?![\w\-\.])|(?=[\-\.](?:\s|$)))/i
      @raw_quote_regex = /(\[quote\s*=\s*["'']?)#{@old_username}(\,?[^\]]*\])/i

      cooked_username = PrettyText::Helpers.format_username(@old_username)
      @cooked_mention_username_regex = /^@#{cooked_username}$/i
      @cooked_mention_user_path_regex = /^\/u(?:sers)?\/#{cooked_username}$/i
      @cooked_quote_username_regex = /(?<=\s)#{cooked_username}(?=:)/i

      update_posts
      update_revisions
      update_notifications
      update_post_custom_fields
    end

    def update_posts
      Post.with_deleted.where(post_conditions("posts.id"), post_condition_args).find_each do |post|
        begin
          post.raw = update_raw(post.raw)
          post.cooked = update_cooked(post.cooked)

          # update without running validations and hooks
          post.update_columns(raw: post.raw, cooked: post.cooked)

          SearchIndexer.index(post, force: true) if post.topic
        rescue => e
          Discourse.warn_exception(e, message: "Failed to update post with id #{post.id}")
        end
      end
    end

    def update_revisions
      PostRevision.where(post_conditions("post_revisions.post_id"), post_condition_args).find_each do |revision|
        begin
          if revision.modifications.key?("raw") || revision.modifications.key?("cooked")
            revision.modifications["raw"]&.map! { |raw| update_raw(raw) }
            revision.modifications["cooked"]&.map! { |cooked| update_cooked(cooked) }
            revision.save!
          end
        rescue => e
          Discourse.warn_exception(e, message: "Failed to update post revision with id #{revision.id}")
        end
      end
    end

    def update_notifications
      params = {
        user_id: @user_id,
        old_username: @old_username,
        new_username: @new_username
      }

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
        WHERE data ILIKE '%' || :old_username || '%'
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

    def post_conditions(post_id_column)
      <<~SQL
        EXISTS(
            SELECT 1
            FROM user_actions AS a
            WHERE a.target_post_id = #{post_id_column} AND
                  a.action_type = :mentioned AND
                  a.user_id = :user_id
        ) OR EXISTS(
            SELECT 1
            FROM quoted_posts AS q
              JOIN posts AS p ON (q.quoted_post_id = p.id)
            WHERE q.post_id = #{post_id_column} AND
              p.user_id = :user_id
        )
      SQL
    end

    def post_condition_args
      { mentioned: UserAction::MENTION, user_id: @user_id }
    end

    def update_raw(raw)
      raw.gsub(@raw_mention_regex, "@#{@new_username}")
        .gsub(@raw_quote_regex, "\\1#{@new_username}\\2")
    end

    # Uses Nokogiri instead of rebake, because it works for posts and revisions
    # and there is no reason to invalidate oneboxes, run the post analyzer etc.
    # when only the username changes.
    def update_cooked(cooked)
      doc = Nokogiri::HTML.fragment(cooked)

      doc.css("a.mention").each do |a|
        a.content = a.content.gsub(@cooked_mention_username_regex, "@#{@new_username}")
        a["href"] = a["href"].gsub(@cooked_mention_user_path_regex, "/u/#{@new_username}") if a["href"]
      end

      doc.css("aside.quote").each do |aside|
        next unless div = aside.at_css("div.title")

        username_replaced = false

        div.children.each do |child|
          if child.text?
            content = child.content
            username_replaced = content.gsub!(@cooked_quote_username_regex, @new_username).present?
            child.content = content if username_replaced
          end
        end

        if username_replaced || quotes_correct_user?(aside)
          div.at_css("img.avatar")&.replace(@avatar_img)
        end
      end

      doc.to_html
    end

    def quotes_correct_user?(aside)
      Post.where(
        topic_id: aside["data-topic"],
        post_number: aside["data-post"]
      ).pluck(:user_id).first == @user_id
    end
  end
end

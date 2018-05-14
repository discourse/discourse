module Jobs
  class UpdateUsername < Jobs::Base

    def execute(args)
      @user_id = args[:user_id]
      @old_username = args[:old_username]
      @new_username = args[:new_username]

      @raw_mention_regex = /(?:(?<![\w`_])|(?<=_))@#{@old_username}(?:(?![\w\-\.])|(?=[\-\.](?:\s|$)))/i
      @raw_quote_regex = /(\[quote\s*=\s*["'']?)#{@old_username}(\,?[^\]]*\])/i
      @cooked_mention_username_regex = /^@#{@old_username}$/i
      @cooked_mention_user_path_regex = /^\/u(?:sers)?\/#{@old_username}$/i
      @cooked_quote_username_regex = /(?<=\s)#{@old_username}(?=:)/i

      update_posts
      update_revisions
      update_notifications
    end

    def update_posts
      Post.with_deleted.where(post_conditions("posts.id"), post_condition_args).find_each do |post|
        post.raw = update_raw(post.raw)
        post.cooked = update_cooked(post.cooked)

        # update without running validations and hooks
        post.update_columns(raw: post.raw, cooked: post.cooked)
      end
    end

    def update_revisions
      PostRevision.where(post_conditions("post_revisions.post_id"), post_condition_args).find_each do |revision|
        revision.modifications["raw"].map! { |raw| update_raw(raw) }
        revision.modifications["cooked"].map! { |cooked| update_cooked(cooked) }
        revision.save!
      end
    end

    def update_notifications
      params = {
        user_id: @user_id,
        old_username: @old_username,
        new_username: @new_username,
        notification_types_with_correct_user_id: [
          Notification.types[:granted_badge],
          Notification.types[:group_message_summary]
        ],
        invitee_accepted_notification_type: Notification.types[:invitee_accepted]
      }

      Notification.exec_sql(<<~SQL, params)
        UPDATE notifications AS n
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
                                        ELSE NULL END
                        )
                    )) :: JSON
        WHERE EXISTS(
                  SELECT 1
                  FROM posts AS p
                  WHERE p.topic_id = n.topic_id
                        AND p.post_number = n.post_number
                        AND p.user_id = :user_id)
              OR (n.notification_type IN (:notification_types_with_correct_user_id) AND n.user_id = :user_id)
              OR (n.notification_type = :invitee_accepted_notification_type
                  AND EXISTS(
                      SELECT 1
                      FROM invites i
                      WHERE i.user_id = :user_id AND n.user_id = i.invited_by_id
                  )
              )
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
        a["href"] = a["href"].gsub(@cooked_mention_user_path_regex, "/u/#{@new_username}")
      end

      doc.css("aside.quote > div.title").each do |div|
        div.children.each do |child|
          child.content = child.content.gsub(@cooked_quote_username_regex, @new_username) if child.text?
        end
        div.at_css("img.avatar")&.replace(avatar_img)
      end

      doc.to_html
    end

    def avatar_img
      @avatar_img ||= PrettyText.avatar_img(User.find_by_id(@user_id).avatar_template, "tiny")
    end
  end
end

module Jobs
  class UpdateUsername < Jobs::Base

    def execute(args)
      @user_id = args[:user_id]

      username = args[:old_username]
      @raw_mention_regex = /(?:(?<![\w`_])|(?<=_))@#{username}(?:(?![\w\-\.])|(?=[\-\.](?:\s|$)))/i
      @raw_quote_regex = /(\[quote\s*=\s*["'']?)#{username}(\,?[^\]]*\])/i
      @cooked_mention_username_regex = /^@#{username}$/i
      @cooked_mention_user_path_regex = /^\/u(?:sers)?\/#{username}$/i
      @cooked_quote_username_regex = /(?<=\s)#{username}(?=:)/i
      @new_username = args[:new_username]

      update_posts
      update_revisions
    end

    def update_posts
      Post.where(post_conditions("posts.id"), post_condition_args).find_each do |post|
        if update_raw!(post.raw)
          post.update_columns(raw: post.raw, cooked: update_cooked(post.cooked))
        end
      end
    end

    def update_revisions
      PostRevision.where(post_conditions("post_revisions.post_id"), post_condition_args).find_each do |revision|
        changed = false

        revision.modifications["raw"]&.each do |raw|
          changed |= update_raw!(raw)
        end

        if changed
          revision.modifications["cooked"].map! { |cooked| update_cooked(cooked) }
          revision.save!
        end
      end
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

    def update_raw!(raw)
      changed = false
      changed |= raw.gsub!(@raw_mention_regex, "@#{@new_username}")
      changed |= raw.gsub!(@raw_quote_regex, "\\1#{@new_username}\\2")
      changed
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
        # TODO Update avatar URL
        div.children.each do |child|
          child.content = child.content.gsub(@cooked_quote_username_regex, @new_username) if child.text?
        end
      end

      doc.to_html
    end
  end
end

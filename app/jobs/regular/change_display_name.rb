# frozen_string_literal: true

module Jobs
  class ChangeDisplayName < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      @user = User.find_by(id: args[:user_id])

      return unless user.present?

      # We need to account for the case where the instance allows
      # name to be empty by falling back to username.
      @old_display_name = (args[:old_name].presence || user.username).unicode_normalize
      @new_display_name = (args[:new_name].presence || user.username).unicode_normalize

      @quote_rewriter = QuoteRewriter.new(user.id)

      update_posts
      update_revisions
    end

    private

    attr_reader :user, :old_display_name, :new_display_name, :quote_rewriter

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
        .where("p.user_id = :user_id", user_id: user.id)
        .find_each { |post| update_post(post) }
    end

    def update_revisions
      PostRevision
        .joins(quoted("post_revisions.post_id"))
        .where("p.user_id = :user_id", user_id: user.id)
        .find_each { |revision| update_revision(revision) }
    end

    def quoted(post_id_column)
      <<~SQL
        JOIN quoted_posts AS q ON (q.post_id = #{post_id_column})
        JOIN posts AS p ON (q.quoted_post_id = p.id)
      SQL
    end

    def update_post(post)
      post.raw = update_raw(post.raw)
      post.cooked = update_cooked(post.cooked)

      post.update_columns(raw: post.raw, cooked: post.cooked)

      SearchIndexer.index(post, force: true) if post.topic
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update post with id #{post.id}")
    end

    def update_revision(revision)
      if revision.modifications["raw"] || revision.modifications["cooked"]
        revision.modifications["raw"].map! { |raw| update_raw(raw) }
        revision.modifications["cooked"].map! { |cooked| update_cooked(cooked) }
        revision.save!
      end
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update post revision with id #{revision.id}")
    end

    def update_raw(raw)
      @quote_rewriter.rewrite_raw(raw.gsub(@raw_mention_regex, "@#{@new_username}"))
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

      @quote_rewriter.rewrite_cooked(doc)

      doc.to_html
    end

    def quotes_correct_user?(aside)
      Post.exists?(
        topic_id: aside["data-topic"],
        post_number: aside["data-post"],
        user_id: @user_id,
      )
    end
  end
end

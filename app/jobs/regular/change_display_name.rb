# frozen_string_literal: true

module Jobs
  class ChangeDisplayName < ::Jobs::Base
    sidekiq_options queue: "low"

    # Avoid race conditions if a user's name is updated several times
    # in quick succession.
    cluster_concurrency 1

    def execute(args)
      @user = User.find_by(id: args[:user_id])

      return if user.blank?

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
      @quote_rewriter.rewrite_raw_display_name(raw, old_display_name, new_display_name)
    end

    # Uses Nokogiri instead of rebake, because it works for posts and revisions
    # and there is no reason to invalidate oneboxes, run the post analyzer etc.
    # when only the display name changes.
    def update_cooked(cooked)
      doc = Nokogiri::HTML5.fragment(cooked)

      @quote_rewriter.rewrite_cooked_display_name(doc, old_display_name, new_display_name)

      doc.to_html
    end
  end
end

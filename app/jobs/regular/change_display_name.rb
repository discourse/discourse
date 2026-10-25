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
      post.with_lock do
        rewritten = update_content(post.raw, post.cooked)
        if post.form_data
          submission =
            FormTemplate::Submission
              .new(post.form_data)
              .rewrite_text { |text| update_content(text, nil)[:raw] }
          rewritten[:form_data] = submission.to_h
          rewritten[:raw] = submission.normalized_raw
          rewritten[:cooked] = post.cook(rewritten[:raw])
          PostRevisor
            .new(post)
            .rewrite_cached_original do |field, value|
              case field
              when :raw
                update_content(value, nil)[:raw]
              when :cooked
                value
              when :form_data
                value &&
                  FormTemplate::Submission
                    .new(value, validate: false)
                    .rewrite_text { |text| update_content(text, nil)[:raw] }
                    .to_h
              end
            end
        end
        post.update_columns(rewritten)
      end
      post.sync_first_post_caches

      SearchIndexer.index(post, force: true) if post.topic
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update post with id #{post.id}")
    end

    def update_revision(revision)
      revision.with_lock do
        raw_versions = revision.modifications["raw"]
        cooked_versions = revision.modifications["cooked"]

        raw_versions&.each_index do |index|
          rewritten = update_content(raw_versions[index], cooked_versions&.at(index))
          raw_versions[index] = rewritten[:raw]
          cooked_versions[index] = rewritten[:cooked] if cooked_versions
        end

        revision.rewrite_form_data { |text| update_content(text, nil)[:raw] }
        revision.save! if revision.changed?
      end
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update post revision with id #{revision.id}")
    end

    def update_content(raw, cooked)
      @quote_rewriter.rewrite_display_name(
        raw: raw,
        cooked: cooked,
        old_display_name: old_display_name,
        new_display_name: new_display_name,
        username: user.username,
      )
    end
  end
end

# frozen_string_literal: true

require 'image_sizer'

module Jobs

  class ProcessPost < ::Jobs::Base

    def execute(args)
      DistributedMutex.synchronize("process_post_#{args[:post_id]}", validity: 10.minutes) do
        post = Post.find_by(id: args[:post_id])
        # two levels of deletion
        return unless post.present? && post.topic.present?

        orig_cooked = post.cooked
        recooked = nil

        if args[:cook].present?
          cooking_options = args[:cooking_options] || {}
          cooking_options[:topic_id] = post.topic_id
          recooked = post.cook(post.raw, cooking_options.symbolize_keys)
          post.update_columns(cooked: recooked, baked_at: Time.zone.now, baked_version: Post::BAKED_VERSION)
        end

        cp = CookedPostProcessor.new(post, args)
        cp.post_process(new_post: args[:new_post])

        # If we changed the document, save it
        cooked = cp.html

        if cooked != (recooked || orig_cooked)
          if orig_cooked.present? && cooked.blank?
            # TODO stop/restart the worker if needed, let's gather a few here first
            Rails.logger.warn("Cooked post processor in FATAL state, bypassing. You need to urgently restart sidekiq\norig: #{orig_cooked}\nrecooked: #{recooked}\ncooked: #{cooked}\npost id: #{post.id}")
          else
            post.update_column(:cooked, cp.html)
            post.topic.update_excerpt(post.excerpt_for_topic) if post.is_first_post?
            extract_links(post)
            auto_tag(post) if SiteSetting.tagging_enabled? && post.post_number == 1
            post.publish_change_to_clients! :revised
          end
        end

        if !post.user&.staff? && !post.user&.staged?
          s = post.raw
          s << " #{post.topic.title}" if post.post_number == 1
          if !args[:bypass_bump] && WordWatcher.new(s).should_flag?
            PostActionCreator.create(
              Discourse.system_user,
              post,
              :inappropriate,
              reason: :watched_word
            )
          end
        end
      end
    end

    # onebox may have added some links, so extract them now
    def extract_links(post)
      TopicLink.extract_from(post)
      QuotedPost.extract_from(post)
    end

    def auto_tag(post)
      watched_words = WordWatcher.get_cached_words(:tag)
      return if watched_words.blank?

      word_watcher = WordWatcher.new(post.raw)

      old_tags = post.topic.tags.pluck(:name).to_set
      new_tags = old_tags.dup

      watched_words.each do |word, tags|
        new_tags += tags.split(",") if word_watcher.matches?(word)
      end

      if old_tags != new_tags
        post.revise(
          Discourse.system_user,
          tags: new_tags.to_a,
          edit_reason: I18n.t(:watched_words_auto_tag)
        )
      end
    end
  end

end

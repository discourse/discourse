require 'image_sizer'
require_dependency 'cooked_post_processor'

module Jobs

  class ProcessPost < Jobs::Base

    def execute(args)
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
      cp.post_process(bypass_bump: args[:bypass_bump], new_post: args[:new_post])

      # If we changed the document, save it
      cooked = cp.html

      if cooked != (recooked || orig_cooked)

        if orig_cooked.present? && cooked.blank?
          # TODO suicide if needed, let's gather a few here first
          Rails.logger.warn("Cooked post processor in FATAL state, bypassing. You need to urgently restart sidekiq\norig: #{orig_cooked}\nrecooked: #{recooked}\ncooked: #{cooked}\npost id: #{post.id}")
        else
          post.update_column(:cooked, cp.html)
          extract_links(post)
          post.publish_change_to_clients! :revised
        end
      end

      if !post.user&.staff? && !post.user&.staged?
        s = post.cooked
        s << " #{post.topic.title}" if post.post_number == 1
        if !args[:bypass_bump] && WordWatcher.new(s).should_flag?
          PostActionCreator.create(Discourse.system_user, post, :inappropriate)
        end
      end
    end

    # onebox may have added some links, so extract them now
    def extract_links(post)
      TopicLink.extract_from(post)
      QuotedPost.extract_from(post)
    end
  end

end

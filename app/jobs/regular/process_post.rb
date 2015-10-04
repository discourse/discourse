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
        post.update_column(:cooked, recooked)
      end

      cp = CookedPostProcessor.new(post, args)
      cp.post_process(args[:bypass_bump])

      # If we changed the document, save it
      cooked = cp.html

      if cooked != (recooked || orig_cooked)

        if orig_cooked.present? && cooked.blank?
          # TODO suicide if needed, let's gather a few here first
          Rails.logger.warn("Cooked post processor in FATAL state, bypassing. You need to urgently restart sidekiq\norig: #{orig_cooked}\nrecooked: #{recooked}\ncooked: #{cooked}\npost id: #{post.id}")
        else
          post.update_column(:cooked, cp.html)
          post.publish_change_to_clients! :revised
        end
      end
    end

  end

end

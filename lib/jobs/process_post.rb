require 'image_sizer'
require_dependency 'cooked_post_processor'

module Jobs

  class ProcessPost < Jobs::Base

    def execute(args)
      post = Post.where(id: args[:post_id]).first
      # two levels of deletion
      return unless post.present? && post.topic.present?

      if args[:cook].present?
        post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
      end

      cp = CookedPostProcessor.new(post, args)
      cp.post_process

      # If we changed the document, save it
      post.update_column(:cooked, cp.html) if cp.dirty?
    end

  end

end

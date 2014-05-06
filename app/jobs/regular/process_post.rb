require 'image_sizer'
require_dependency 'cooked_post_processor'

module Jobs

  class ProcessPost < Jobs::Base

    def execute(args)
      post = Post.find_by(id: args[:post_id])
      # two levels of deletion
      return unless post.present? && post.topic.present?

      post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id)) if args[:cook].present?

      cp = CookedPostProcessor.new(post, args)
      cp.post_process(args[:bypass_bump])

      # If we changed the document, save it
      post.update_column(:cooked, cp.html) if cp.dirty?
    end

  end

end

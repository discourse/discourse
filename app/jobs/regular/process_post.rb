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
      if cp.dirty?
        post.update_column(:cooked, cp.html)

        MessageBus.publish("/topic/#{post.topic_id}", {
            type: "revised",
            id: post.id,
            updated_at: Time.now,
            post_number: post.post_number
        }, group_ids: post.topic.secure_group_ids )
      end
    end

  end

end

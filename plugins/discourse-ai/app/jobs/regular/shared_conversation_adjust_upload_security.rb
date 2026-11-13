# frozen_string_literal: true

module Jobs
  class SharedConversationAdjustUploadSecurity < ::Jobs::Base
    def execute(args)
      if args[:conversation_id].present?
        # The conversation context includes post cooked content so this
        # must be updated when target uploads security changes.
        update_conversation(args[:conversation_id])
      elsif args[:target_id].present? && args[:target_type].present?
        # If we deleted the conversation then we just need to update the target's
        # uploads security, no need to update the conversation.
        update_target(args[:target_id], args[:target_type])
      end
    end

    private

    def update_conversation(conversation_id)
      conversation = SharedAiConversation.find_by(id: conversation_id)
      return if conversation.blank?

      # NOTE: Only Topics are supported for now, in future we will need a more flexible
      # way of doing this.
      if conversation.target_type == "Topic"
        topic = conversation.target_topic
        return if topic.blank?

        rebaked_posts = TopicUploadSecurityManager.new(topic).run

        if rebaked_posts.any?
          conversation.with_lock do
            posts_by_id =
              Post
                .with_deleted
                .where(id: rebaked_posts.map(&:id))
                .select(:id, :cooked)
                .index_by(&:id)
            new_context =
              conversation.context.map do |context_post|
                if (rebaked_post = posts_by_id[context_post["id"]])
                  artifact_ids = []
                  context_post["cooked"] = SharedAiConversation.cook_artifacts(
                    rebaked_post,
                    artifact_ids: artifact_ids,
                  )
                  context_post["artifact_ids"] = Array(context_post["artifact_ids"]) & artifact_ids
                end
                context_post
              end

            conversation.update!(context: new_context)
          end
        end
      end
    end

    def update_target(target_id, target_type)
      # NOTE: Only Topics are supported for now, in future we will need a more flexible
      # way of doing this.
      if target_type == "Topic"
        topic = Topic.with_deleted.find_by(id: target_id)
        return if topic.blank?

        TopicUploadSecurityManager.new(topic).run
      end
    end
  end
end

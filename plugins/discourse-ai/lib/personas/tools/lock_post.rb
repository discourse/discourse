# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class LockPost < Tool
        def self.signature
          {
            name: name,
            description: "Locks or unlocks a post based on the locked parameter.",
            parameters: [
              {
                name: "post_id",
                description: "The ID of the post",
                type: "integer",
                required: true,
              },
              {
                name: "locked",
                description: "true to lock the post, false to unlock it",
                type: "boolean",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the post is being locked or unlocked",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "lock_post"
        end

        def invoke
          post = Post.find_by(id: parameters[:post_id])
          return error_response(I18n.t("discourse_ai.ai_bot.lock_post.errors.not_found")) if !post

          if !guardian.can_lock_post?(post)
            return error_response(I18n.t("discourse_ai.ai_bot.lock_post.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.lock_post.errors.no_reason"))
          end

          locker = PostLocker.new(post, acting_user)

          if !!parameters[:locked]
            locker.lock
          else
            locker.unlock
          end

          { status: "success", message: I18n.t("discourse_ai.ai_bot.lock_post.success") }
        end

        def description_args
          { post_id: parameters[:post_id], locked: parameters[:locked] }
        end
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class FlagPost < Tool
        FLAG_TYPES = %w[
          review
          review_hide
          review_delete
          review_delete_silence
          spam
          spam_silence
        ].freeze

        def self.signature
          {
            name: name,
            description: "Flags the current post for review when flag_post is true.",
            parameters: [
              {
                name: "flag_post",
                description: "Whether the post should be flagged",
                type: "boolean",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the post should be flagged",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.accepted_options
          [option(:flag_type, type: :enum, values: FLAG_TYPES, default: "review")]
        end

        def self.name
          "flag_post"
        end

        def flag_post
          !!parameters[:flag_post]
        end

        def reason
          parameters[:reason].to_s.strip
        end

        def flag_type
          persona_flag_type = persona_option(:flag_type)
          (persona_flag_type.presence || feature_context[:flag_type].presence || "review").to_s
        end

        def invoke
          return error_response(I18n.t("discourse_ai.ai_bot.flag_post.errors.no_context")) if !post
          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.flag_post.errors.no_reason"))
          end
          if !FLAG_TYPES.include?(flag_type)
            return error_response(I18n.t("discourse_ai.ai_bot.flag_post.errors.invalid_flag_type"))
          end

          if !flag_post
            return { status: "skipped", message: I18n.t("discourse_ai.ai_bot.flag_post.skipped") }
          end

          if already_flagged?
            return(
              {
                status: "skipped",
                message: I18n.t("discourse_ai.ai_bot.flag_post.already_flagged"),
              }
            )
          end

          flag_success = true
          if %w[spam spam_silence].include?(flag_type)
            result =
              PostActionCreator.new(
                Discourse.system_user,
                post,
                PostActionType.types[:spam],
                message: flag_reason,
                queue_for_review: true,
              ).perform
            flag_success = result.success?

            if flag_type == "spam_silence"
              if flag_success
                SpamRule::AutoSilence.new(post.user, post).silence_user
              else
                Rails.logger.warn(
                  "flag_post: unable to flag post as spam, post action failed for #{post.id} with error: '#{result.errors.full_messages.join(",").truncate(3000)}'",
                )
              end
            end
          else
            reviewable =
              ReviewablePost.needs_review!(
                target: post,
                created_by: Discourse.system_user,
                reviewable_by_moderator: true,
              )
            reviewable.add_score(
              Discourse.system_user,
              ReviewableScore.types[:needs_approval],
              reason: flag_reason,
              force_review: true,
            )

            if flag_type == "review_hide"
              post.hide!(PostActionType.types[:notify_moderators])
            elsif %w[review_delete review_delete_silence].include?(flag_type)
              PostDestroyer.new(Discourse.system_user, post, context: "flag_post").destroy

              if flag_type == "review_delete_silence"
                UserSilencer.silence(
                  post.user,
                  Discourse.system_user,
                  message: :silenced_by_staff,
                  post_id: @post&.id,
                )
              end
            end
          end

          { status: "flagged", message: I18n.t("discourse_ai.ai_bot.flag_post.flagged") }
        end

        def description_args
          { post_id: post&.id, flag_post: flag_post, flag_type: flag_type }
        end

        private

        def post
          @post ||= Post.find_by(id: context.post_id)
        end

        def already_flagged?
          ReviewableScore
            .pending
            .where(
              user: Discourse.system_user,
              reviewable_score_type: [
                ReviewableScore.types[:spam],
                ReviewableScore.types[:needs_approval],
              ],
            )
            .joins(:reviewable)
            .where(reviewables: { target: post })
            .exists?
        end

        def flag_reason
          if feature_context[:automation_id].present? && feature_context[:automation_name].present?
            I18n.t(
              "discourse_automation.scriptables.llm_triage.flagged_post",
              base_path: feature_context[:base_path] || Discourse.base_path,
              llm_response: feature_context[:llm_response].presence || reason,
              automation_id: feature_context[:automation_id].to_s,
              automation_name: feature_context[:automation_name].to_s,
            )
          else
            I18n.t("discourse_ai.ai_bot.flag_post.reason", reason: reason)
          end
        end

        def error_response(message)
          { status: "error", error: message }
        end

        def feature_context
          return {} if !context.respond_to?(:feature_context)

          context.feature_context || {}
        end

        def persona_option(name)
          return nil if !persona_options.is_a?(Hash)
          return nil if !persona_options.key?(name)

          persona_options[name]
        end
      end
    end
  end
end

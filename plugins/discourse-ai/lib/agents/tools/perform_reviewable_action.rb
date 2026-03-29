# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class PerformReviewableAction < Tool
        def self.signature
          {
            name: name,
            description:
              "Performs an action on a review queue item. Use list_reviewables first to discover available actions for each item. Common actions include: agree_and_keep, agree_and_hide, disagree, ignore_and_do_nothing, delete_and_agree, approve_post, reject_post, approve_user, delete_user.",
            parameters: [
              {
                name: "reviewable_id",
                description: "The ID of the reviewable item to act on",
                type: "integer",
                required: true,
              },
              {
                name: "action_id",
                description:
                  "The action to perform (e.g. agree_and_keep, agree_and_hide, disagree, ignore_and_do_nothing, delete_and_agree, approve_post, reject_post, approve_user, delete_user)",
                type: "string",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why this action is being taken",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "perform_reviewable_action"
        end

        def self.requires_approval?
          false
        end

        def invoke
          if !guardian.can_see_review_queue?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.perform_reviewable_action.errors.not_allowed"),
              )
            )
          end

          if reason.blank?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.perform_reviewable_action.errors.no_reason"),
              )
            )
          end

          reviewable = Reviewable.viewable_by(guardian.user).find_by(id: parameters[:reviewable_id])
          if !reviewable
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.perform_reviewable_action.errors.not_found"),
              )
            )
          end

          action_id = parameters[:action_id].to_s.to_sym
          available_actions = reviewable.actions_for(guardian)
          valid_action_ids =
            available_actions.bundles.flat_map do |bundle|
              bundle.actions.map { |a| a.server_action.to_sym }
            end

          if !valid_action_ids.include?(action_id)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.perform_reviewable_action.errors.invalid_action",
                  action: action_id,
                  available: valid_action_ids.join(", "),
                ),
              )
            )
          end

          reviewable.reviewable_notes.create!(user: acting_user, content: reason)

          begin
            result =
              reviewable.perform(
                acting_user,
                action_id,
                version: reviewable.version,
                guardian: guardian,
              )
          rescue Reviewable::InvalidAction
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.perform_reviewable_action.errors.invalid_action",
                  action: action_id,
                  available: valid_action_ids.join(", "),
                ),
              )
            )
          rescue Reviewable::UpdateConflict
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.perform_reviewable_action.errors.conflict"),
              )
            )
          end

          if result.success?
            {
              status: "success",
              message:
                I18n.t(
                  "discourse_ai.ai_bot.perform_reviewable_action.success",
                  action: action_id,
                  reviewable_id: reviewable.id,
                ),
            }
          else
            error_response(
              result.errors&.full_messages&.join(", ").presence ||
                I18n.t("discourse_ai.ai_bot.perform_reviewable_action.errors.action_failed"),
            )
          end
        end

        def description_args
          { reviewable_id: parameters[:reviewable_id], action: parameters[:action_id] }
        end
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module FlagPost
      class V1 < NodeType
        FLAG_TYPES = %w[
          review
          review_hide
          review_delete
          review_delete_silence
          spam
          spam_silence
        ].freeze
        SPAM_FLAG_TYPES = %w[spam spam_silence].freeze

        description(
          name: "action:flag_post",
          version: "1.0",
          defaults: {
            icon: "flag",
            color: "red",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [
            {
              schema: {
                "$schema" => Schema::DRAFT_URI,
                "type" => "object",
                "properties" => {
                  "post_id" => {
                    "type" => "integer",
                  },
                  "flag_type" => {
                    "type" => "string",
                  },
                  "reviewable_id" => {
                    "type" => "integer",
                  },
                  "post_hidden" => {
                    "type" => "boolean",
                  },
                  "post_deleted" => {
                    "type" => "boolean",
                  },
                  "user_silenced" => {
                    "type" => "boolean",
                  },
                },
              },
            },
          ],
          properties: {
            post_id: {
              type: :string,
              required: true,
            },
            flag_type: {
              type: :options,
              required: true,
              options: FLAG_TYPES,
              default: "review",
              ui: {
                expression: true,
              },
            },
            reason: {
              type: :string,
              required: false,
              ui: {
                control: :textarea,
              },
            },
            **actor_property,
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "post_id" => exec_ctx.get_node_parameter("post_id", item_index),
                "flag_type" =>
                  exec_ctx.get_node_parameter("flag_type", item_index, default: "review"),
                "reason" => exec_ctx.get_node_parameter("reason", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          flag_type = config["flag_type"].to_s
          if !FLAG_TYPES.include?(flag_type)
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.flag_post.unknown_flag_type",
                flag_type: flag_type,
              ),
            )
          end

          post = ::Post.find(config["post_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          if !actor.staff?
            raise_node_error!(I18n.t("discourse_workflows.errors.flag_post.actor_not_staff"))
          end
          raise Discourse::InvalidAccess if !actor.guardian.can_see?(post)

          reason = score_reason_for(exec_ctx, config["reason"], item_index)
          context = DiscourseWorkflows.reviewable_score_context(exec_ctx.get_workflow.id)

          reviewable =
            if SPAM_FLAG_TYPES.include?(flag_type)
              flag_as_spam(post, actor, flag_type, reason, context)
            else
              add_to_review_queue(
                post,
                actor,
                flag_type,
                reason,
                attribution_for(exec_ctx, item_index),
                context,
              )
            end

          output(post, flag_type, reviewable)
        end

        def attribution_for(exec_ctx, item_index, escape: false)
          DiscourseWorkflows.review_attribution(
            exec_ctx,
            item_index:,
            flag_type: :flag_post,
            escape:,
          )
        end

        def score_reason_for(exec_ctx, custom_reason, item_index)
          parts = [attribution_for(exec_ctx, item_index, escape: true)]
          custom_reason = custom_reason.to_s.strip
          parts << custom_reason if custom_reason.present?
          parts.join("<br>")
        end

        def flag_as_spam(post, actor, flag_type, reason, context)
          if !actor.guardian.post_can_act?(post, :spam)
            raise_node_error!(I18n.t("discourse_workflows.errors.flag_post.cannot_flag"))
          end

          promote_pending_reviewable_to_flagged!(post)

          result =
            PostActionCreator.new(
              actor,
              post,
              PostActionType.types[:spam],
              reason: reason,
              context: context,
              queue_for_review: true,
            ).perform

          if !result.success?
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.flag_post.flag_failed",
                errors: result.errors.full_messages.join(", "),
              ),
            )
          end

          if flag_type == "spam_silence" && post.user.present?
            SpamRule::AutoSilence.new(post.user, post).silence_user
          end

          result.reviewable
        end

        def add_to_review_queue(post, actor, flag_type, reason, attribution, context)
          destroying = %w[review_delete review_delete_silence].include?(flag_type)

          if destroying
            PostDestroyer.new(actor, post, context: attribution).destroy

            if flag_type == "review_delete_silence" && post.user.present?
              UserSilencer.silence(post.user, actor, message: :silenced_by_staff, post_id: post.id)
            end
          end

          reviewable =
            (ReviewableFlaggedPost.pending.find_by(target: post) if !destroying) ||
              ReviewablePost.needs_review!(
                target: post,
                created_by: actor,
                reviewable_by_moderator: true,
              )

          add_review_score(reviewable, actor, reason, context)

          post.hide!(PostActionType.types[:notify_moderators]) if flag_type == "review_hide"

          reviewable
        end

        def add_review_score(reviewable, actor, reason, context)
          score_type = ReviewableScore.types[:needs_approval]
          if reviewable.reviewable_scores.pending.exists?(
               user_id: actor.id,
               reviewable_score_type: score_type,
               context: context,
             )
            return
          end

          reviewable.add_score(
            actor,
            score_type,
            reason: reason,
            context: context,
            force_review: true,
          )
        end

        def promote_pending_reviewable_to_flagged!(post)
          reviewable = ReviewablePost.pending.find_by(target: post)
          return if reviewable.blank?
          return if ReviewableFlaggedPost.exists?(target: post)

          reviewable.update!(
            type: ReviewableFlaggedPost.name,
            potential_spam: true,
            reviewable_by_moderator: true,
            payload: {
              targets_topic: false,
            },
          )
        rescue ActiveRecord::RecordNotUnique
          raise if !ReviewableFlaggedPost.exists?(target: post)
        end

        def output(post, flag_type, reviewable)
          post.reload
          {
            post_id: post.id,
            flag_type: flag_type,
            reviewable_id: reviewable&.id,
            post_hidden: post.hidden?,
            post_deleted: post.deleted_at.present?,
            user_silenced: post.user&.reload&.silenced? || false,
          }
        end
      end
    end
  end
end

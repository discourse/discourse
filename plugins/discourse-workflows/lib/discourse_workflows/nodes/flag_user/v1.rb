# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module FlagUser
      class V1 < NodeType
        # A fixed reason so the review queue renders a translated sentence rather
        # than a workflow-supplied string. Provenance lives in a note.
        SCORE_REASON = "workflow_flagged_user"

        description(
          name: "action:flag_user",
          version: "1.0",
          defaults: {
            icon: "user-xmark",
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
                  "user_id" => {
                    "type" => "integer",
                  },
                  "username" => {
                    "type" => "string",
                  },
                  "reviewable_id" => {
                    "type" => "integer",
                  },
                  "reviewable_status" => {
                    "type" => "string",
                  },
                  "reviewable_created" => {
                    "type" => "boolean",
                  },
                  "score_added" => {
                    "type" => "boolean",
                  },
                  "user_approved" => {
                    "type" => "boolean",
                  },
                },
              },
            },
          ],
          properties: {
            username: {
              type: :string,
              required: true,
              ui: {
                control: :user,
              },
            },
            reason: {
              type: :string,
              required: false,
              ui: {
                control: :textarea,
              },
            },
            reopen_resolved: {
              type: :boolean,
              required: false,
              default: false,
              ui: {
                control: :boolean,
                expression: true,
              },
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "username" => exec_ctx.get_node_parameter("username", item_index),
                "reason" => exec_ctx.get_node_parameter("reason", item_index),
                "reopen_resolved" =>
                  exec_ctx.get_node_parameter("reopen_resolved", item_index, default: false),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          if !actor.staff?
            raise_node_error!(I18n.t("discourse_workflows.errors.flag_user.actor_not_staff"))
          end

          user = exec_ctx.find_user(username: config["username"])
          ensure_flaggable!(user)

          resolved = resolved_reviewable_for(user)
          if resolved.present? && !config["reopen_resolved"]
            add_already_resolved_hint(exec_ctx, user, resolved)
            return output(user, resolved, created: false, score_added: false)
          end

          reviewable =
            ::ReviewableUser.needs_review!(
              target: user,
              created_by: actor,
              reviewable_by_moderator: true,
              potential_spam: false,
              payload: reviewable_payload(user),
            )
          score_added = add_review_score(reviewable, actor)
          add_provenance_note(exec_ctx, reviewable, actor, config["reason"])

          output(
            user,
            reviewable,
            created: reviewable.created_new.present?,
            score_added: score_added,
          )
        end

        def ensure_flaggable!(user)
          return if !user.staff? && !user.bot?

          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.flag_user.cannot_flag_staff",
              username: user.username,
            ),
          )
        end

        def resolved_reviewable_for(user)
          ::ReviewableUser
            .where(target: user)
            .where.not(status: ::Reviewable.statuses[:pending])
            .first
        end

        def reviewable_payload(user)
          profile = user.user_profile

          {
            username: user.username,
            name: user.name,
            email: user.email,
            bio: profile&.bio_raw,
            website: profile&.website,
          }
        end

        def add_review_score(reviewable, actor)
          score_type = ::ReviewableScore.types[:needs_approval]

          if reviewable.reviewable_scores.pending.exists?(
               user_id: actor.id,
               reviewable_score_type: score_type,
               reason: SCORE_REASON,
             )
            return false
          end

          reviewable.add_score(actor, score_type, reason: SCORE_REASON, force_review: true)
          true
        end

        def add_provenance_note(exec_ctx, reviewable, actor, custom_reason)
          parts = [
            I18n.t(
              "discourse_workflows.flag_user.flagged_by_workflow",
              workflow_name: exec_ctx.get_workflow.name,
            ),
          ]
          custom_reason = custom_reason.to_s.strip
          parts << custom_reason if custom_reason.present?

          content = parts.join("\n\n").truncate(::ReviewableNote::MAX_CONTENT_LENGTH)
          return if reviewable.reviewable_notes.exists?(user_id: actor.id, content: content)

          reviewable.reviewable_notes.create!(user: actor, content: content)
        end

        def add_already_resolved_hint(exec_ctx, user, reviewable)
          exec_ctx.add_execution_hints(
            {
              message:
                I18n.t(
                  "discourse_workflows.hints.flag_user.already_resolved",
                  username: user.username,
                  status: reviewable.status,
                ),
              location: "outputPane",
            },
          )
        end

        def output(user, reviewable, created:, score_added:)
          {
            user_id: user.id,
            username: user.username,
            reviewable_id: reviewable.id,
            reviewable_status: reviewable.status,
            reviewable_created: created,
            score_added: score_added,
            user_approved: user.approved?,
          }
        end
      end
    end
  end
end

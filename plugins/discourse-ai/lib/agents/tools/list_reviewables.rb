# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ListReviewables < Tool
        def self.signature
          {
            name: name,
            description:
              "Lists pending review queue items. Can filter by reviewable type and age. Returns a summary of each item including its ID, type, score, creation date, target details, and available actions.",
            parameters: [
              {
                name: "type",
                description:
                  "Filter by reviewable type: ReviewableFlaggedPost, ReviewableQueuedPost, ReviewableUser, ReviewablePost. Leave blank for all types.",
                type: "string",
              },
              {
                name: "min_hours_old",
                description:
                  "Only return items that have been in the queue for at least this many hours",
                type: "integer",
              },
              {
                name: "max_hours_old",
                description:
                  "Only return items that have been in the queue for at most this many hours",
                type: "integer",
              },
              { name: "category_id", description: "Filter by category ID", type: "integer" },
              {
                name: "status",
                description:
                  "Filter by status: pending (default), approved, rejected, ignored, deleted",
                type: "string",
              },
            ],
          }
        end

        def self.name
          "list_reviewables"
        end

        def self.requires_approval?
          false
        end

        def invoke
          if !guardian.can_see_review_queue?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.list_reviewables.errors.not_allowed"))
            )
          end

          status = (parameters[:status] || "pending").to_sym
          allowed_statuses = Reviewable.statuses.symbolize_keys.keys + %i[reviewed all]
          if !allowed_statuses.include?(status)
            return(
              error_response(I18n.t("discourse_ai.ai_bot.list_reviewables.errors.invalid_status"))
            )
          end

          filters = { status: status, limit: 20 }

          if parameters[:type].present?
            unless Reviewable.valid_type?(parameters[:type])
              return(
                error_response(I18n.t("discourse_ai.ai_bot.list_reviewables.errors.invalid_type"))
              )
            end
            filters[:type] = parameters[:type]
          end

          filters[:category_id] = parameters[:category_id] if parameters[:category_id].present?

          if parameters[:min_hours_old].present?
            filters[:to_date] = parameters[:min_hours_old].to_i.hours.ago
          end

          if parameters[:max_hours_old].present?
            filters[:from_date] = parameters[:max_hours_old].to_i.hours.ago
          end

          reviewables = Reviewable.list_for(guardian.user, **filters).to_a

          if reviewables.empty?
            return(
              {
                status: "success",
                message: I18n.t("discourse_ai.ai_bot.list_reviewables.empty"),
                reviewables: [],
              }
            )
          end

          rows = reviewables.map { |r| serialize_reviewable(r) }

          {
            status: "success",
            message: I18n.t("discourse_ai.ai_bot.list_reviewables.found", count: rows.size),
            reviewables: rows,
          }
        end

        def description_args
          { type: parameters[:type] || "all", count: 0 }
        end

        private

        def serialize_reviewable(reviewable)
          result = {
            id: reviewable.id,
            type: reviewable.type,
            status: reviewable.status,
            score: reviewable.score.to_f.round(1),
            created_at: reviewable.created_at.iso8601,
            hours_old: ((::Time.zone.now - reviewable.created_at) / 1.hour).round(1),
            category_id: reviewable.category_id,
            topic_id: reviewable.topic_id,
          }

          if reviewable.target_created_by
            result[:target_created_by] = reviewable.target_created_by.username
          end

          result[:created_by] = reviewable.created_by.username if reviewable.created_by

          result[:available_actions] = available_action_ids(reviewable)

          case reviewable
          when ReviewableFlaggedPost
            serialize_flagged_post(result, reviewable)
          when ReviewableQueuedPost
            serialize_queued_post(result, reviewable)
          when ReviewableUser
            serialize_user(result, reviewable)
          when ReviewablePost
            serialize_post(result, reviewable)
          end

          result[:scores] = reviewable.reviewable_scores.map do |score|
            {
              reason: score.reason,
              score: score.score.to_f.round(1),
              status: score.status,
              user: score.user&.username,
            }
          end

          result
        end

        def available_action_ids(reviewable)
          actions = reviewable.actions_for(guardian)
          actions.bundles.flat_map { |bundle| bundle.actions.map { |a| a.server_action } }
        end

        def serialize_flagged_post(result, reviewable)
          post = reviewable.post
          return unless post

          result[:post_id] = post.id
          result[:post_number] = post.post_number
          result[:post_excerpt] = post.excerpt(300, strip_links: true, text_entities: true)
          result[:topic_title] = post.topic&.title
        end

        def serialize_queued_post(result, reviewable)
          payload = reviewable.payload || {}
          result[:queued_title] = payload["title"]
          result[:queued_raw_excerpt] = payload["raw"].to_s.truncate(300)
          result[:queued_tags] = payload["tags"]
        end

        def serialize_user(result, reviewable)
          target = reviewable.target
          return unless target

          result[:username] = target.username
          result[:user_id] = target.id
        end

        def serialize_post(result, reviewable)
          post = reviewable.target
          return unless post.is_a?(Post)

          result[:post_id] = post.id
          result[:post_number] = post.post_number
          result[:post_excerpt] = post.excerpt(300, strip_links: true, text_entities: true)
          result[:topic_title] = post.topic&.title
        end
      end
    end
  end
end

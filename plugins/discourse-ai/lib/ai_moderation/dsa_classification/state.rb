# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      # What the decision model judges: why the reviewable was flagged and the public content
      # behind it. Private account data (emails, IPs) never leaves the site.
      class State
        MAX_CONTENT_CHARS = 6000

        def initialize(reviewable)
          @reviewable = reviewable
        end

        def to_s
          [flag_reasons, content.to_s[0, MAX_CONTENT_CHARS]].compact_blank.join("\n\n")
        end

        private

        attr_reader :reviewable

        def flag_reasons
          titles =
            reviewable
              .reviewable_scores
              .map do |score|
                ReviewableScore.type_title(ReviewableScore.types.key(score.reviewable_score_type))
              end
              .compact_blank
              .uniq
          "Flagged as: #{titles.join(", ")}" if titles.present?
        end

        def content
          case reviewable
          when ReviewableQueuedPost
            post_content(title: reviewable.payload["title"], raw: reviewable.payload["raw"])
          when ReviewableUser
            user_content(reviewable.target)
          else
            post = flagged_post
            post_content(title: post.topic&.title, raw: post.raw, author: post.user) if post
          end
        end

        # A flagged post may have been deleted since it was flagged.
        def flagged_post
          if reviewable.target_type == "Post"
            Post.with_deleted.includes(:topic, :user).find_by(id: reviewable.target_id)
          end
        end

        def post_content(title:, raw:, author: reviewable.target_created_by)
          [
            ("Author: #{author.username}" if author),
            ("Topic title: #{title}" if title.present?),
            ("Post:\n#{raw}" if raw.present?),
          ].compact.join("\n")
        end

        def user_content(user)
          return if !user

          profile = user.user_profile
          [
            "Username: #{user.username}",
            ("Name: #{user.name}" if user.name.present?),
            ("Location: #{profile&.location}" if profile&.location.present?),
            ("Website: #{profile&.website}" if profile&.website.present?),
            ("Bio:\n#{profile&.bio_raw}" if profile&.bio_raw.present?),
          ].compact.join("\n")
        end
      end
    end
  end
end

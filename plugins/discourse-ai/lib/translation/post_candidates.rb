# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostCandidates
      # Posts that are eligible for translation based on site settings
      def self.get
        posts =
          Post
            .where(
              "posts.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
            .where(deleted_at: nil)
            .where("posts.user_id > 0")
            .where.not(raw: [nil, ""])

        posts = posts.joins(:topic)
        if SiteSetting.ai_translation_backfill_limit_to_public_content
          # exclude all PMs
          # and only include posts from public categories
          posts =
            posts
              .where.not(topics: { archetype: Archetype.private_message })
              .where(topics: { category_id: Category.where(read_restricted: false).select(:id) })
        else
          # all regular topics, and group PMs
          posts =
            posts.where(
              "topics.archetype != ? OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              Archetype.private_message,
            )
        end
      end

      def self.get_completion_per_locale(locale)
        done = get.where(locale:).count
        done += PostLocalization.where(locale:).count

        total = get.count

        done / total.to_f
      end
    end
  end
end

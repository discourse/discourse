# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TagCandidates < BaseCandidates
      private

      # all tags that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        tags = Tag.all
        if SiteSetting.ai_translation_backfill_limit_to_public_content
          tags = filter_to_public_tags(tags)
        end
        tags
      end

      def self.filter_to_public_tags(tags)
        # tags visible to everyone are:
        # 1. not in any tag group, OR
        # 2. in a tag group that grants permission to EVERYONE
        everyone_group_id = Group::AUTO_GROUPS[:everyone]
        tags.where(<<~SQL, everyone_group_id)
          tags.id NOT IN (SELECT tag_id FROM tag_group_memberships)
          OR tags.id IN (
            SELECT tgm.tag_id
            FROM tag_group_memberships tgm
            INNER JOIN tag_group_permissions tgp ON tgp.tag_group_id = tgm.tag_group_id
            WHERE tgp.group_id = ?
          )
        SQL
      end

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_tags AS (
            #{get.where.not(tags: { locale: nil }).to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_tags
          ),
          done_count AS (
            SELECT COUNT(DISTINCT t.id)
            FROM eligible_tags t
            LEFT JOIN tag_localizations tl ON t.id = tl.tag_id AND tl.locale LIKE :base_locale
            WHERE t.locale LIKE :base_locale OR tl.tag_id IS NOT NULL
          )
          SELECT d.count AS done, t.count AS total
          FROM total_count t, done_count d
        SQL

        done, total = DB.query_single(sql, base_locale:)
        { done:, total: }
      end
    end
  end
end

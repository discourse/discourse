# frozen_string_literal: true

class DeleteSummariesWithHiddenTags < ActiveRecord::Migration[7.1]
  def up
    # Get all hidden tag names (tags that are restricted and NOT visible to everyone)
    # Group::AUTO_GROUPS[:everyone] is 0
    hidden_tag_names_sql = <<~SQL
      SELECT DISTINCT tags.name
      FROM tags
      INNER JOIN tag_group_memberships ON tags.id = tag_group_memberships.tag_id
      INNER JOIN tag_groups ON tag_group_memberships.tag_group_id = tag_groups.id
      INNER JOIN tag_group_permissions ON tag_groups.id = tag_group_permissions.tag_group_id
      WHERE tags.id NOT IN (
        SELECT tgm.tag_id
        FROM tag_group_memberships tgm
        INNER JOIN tag_group_permissions tgp ON tgm.tag_group_id = tgp.tag_group_id
        WHERE tgp.group_id = 0
      )
    SQL

    hidden_tag_names = DB.query_single(hidden_tag_names_sql)

    return if hidden_tag_names.empty?

    # Delete summaries that might contain hidden tags
    # We err on the side of caution - summaries are cheap to regenerate
    # Use regex for efficient matching of multiple tags in a single query

    # Escape special regex characters and build alternation pattern
    # Example: (tag1|tag2|tag3) matches any of the tags
    escaped_tags = hidden_tag_names.map { |tag| Regexp.escape(tag) }
    regex_pattern = "(#{escaped_tags.join("|")})"

    deleted_count = DB.exec(<<~SQL, regex_pattern)
        DELETE FROM ai_summaries
        WHERE target_type = 'Topic'
          AND summarized_text ~* ?
      SQL

    if deleted_count > 0
      Rails.logger.warn(
        "Deleted #{deleted_count} AI summaries that may contain hidden tags (security fix)",
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

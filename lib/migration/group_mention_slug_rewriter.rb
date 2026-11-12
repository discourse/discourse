# frozen_string_literal: true

module Migration
  # Rewrites @group mentions in post raw when a group slug is renamed during a
  # migration. Boundaries match Jobs::UpdateUsername (not trailing whitespace only).
  module GroupMentionSlugRewriter
    NON_TRAILING_MENTION_CHAR_CLASS = "[:alnum:]_\\-.`"

    module_function

    def update_posts!(old_slug:, new_slug:, group_id:)
      pattern = mention_pattern_sql(old_slug)

      DB.exec(<<~SQL, pattern:, new_slug:, group_id:, old_slug:)
        UPDATE posts AS p SET
          raw = regexp_replace(
            p.raw,
            :pattern,
            E'\\1@' || :new_slug,
            'g'
          ),
          baked_version = NULL
        WHERE p.deleted_at IS NULL
          AND EXISTS (
            SELECT 1
            FROM group_mentions gm
            WHERE gm.post_id = p.id
              AND gm.group_id = :group_id
          )
          AND p.raw LIKE '%@' || :old_slug || '%';
      SQL
    end

    # Ruby equivalent of the SQL pattern for unit tests.
    def rewrite_text(text, old_slug, new_slug)
      text.gsub(mention_pattern_ruby(old_slug), "\\1@#{new_slug}")
    end

    def mention_pattern_sql(old_slug)
      "(^|[^#{NON_TRAILING_MENTION_CHAR_CLASS}])@#{Regexp.escape(old_slug)}(?=[^#{NON_TRAILING_MENTION_CHAR_CLASS}]|$)"
    end

    def mention_pattern_ruby(old_slug)
      /(^|[^#{NON_TRAILING_MENTION_CHAR_CLASS}])@#{Regexp.escape(old_slug)}(?=[^#{NON_TRAILING_MENTION_CHAR_CLASS}]|$)/
    end
  end
end

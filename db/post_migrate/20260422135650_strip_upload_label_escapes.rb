# frozen_string_literal: true

# One-off cleanup for posts whose upload markdown labels accumulated backslash
# escapes through repeated rich-editor edits (regression from
# https://meta.discourse.org/t/401231). The backslashes doubled on each save
# (1 → 2 → 4 → … → 2^N). The engine-side fix prevents further damage; this
# heals existing posts.
#
# Batched + non-transactional so we never hold update locks across the whole
# posts table at once on large sites.
#
# Pattern: strip runs of `\` that escape `_ * ~ | `` inside a label closing
# with `](upload://…`. `\\+` swallows the whole run; the `(?=…)` lookahead
# scopes the match to upload labels — forbidding `[`/`]` in the gap means an
# escape only matches while it sits inside the label that ends in
# `](upload://`, so user-written escapes elsewhere stay intact. Scoping on the
# lookahead alone (rather than consuming the opening `[`) lets a single pass
# strip every escape in a label, e.g. `foo\_bar\_baz`, not just the first.
class StripUploadLabelEscapes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    min_id, max_id = DB.query_single("SELECT MIN(id), MAX(id) FROM posts")
    return if max_id.nil?

    current_id = min_id
    while current_id <= max_id
      DB.exec(<<~SQL, start_id: current_id, end_id: current_id + BATCH_SIZE)
        UPDATE posts
        SET raw = regexp_replace(
          raw,
          '\\\\+([_*~|`])(?=[^\\]\\[]*\\]\\(upload://)',
          '\\1',
          'g'
        )
        WHERE id >= :start_id
          AND id < :end_id
          AND raw ~ '\\\\+[_*~|`][^\\]\\[]*\\]\\(upload://'
      SQL
      current_id += BATCH_SIZE
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

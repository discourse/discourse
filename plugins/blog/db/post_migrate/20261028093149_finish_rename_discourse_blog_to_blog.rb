# frozen_string_literal: true

class FinishRenameDiscourseBlogToBlog < ActiveRecord::Migration[8.1]
  RENAMED_TYPES = {
    "DiscourseBlog::Review" => "Blog::Review",
    "DiscourseBlog::Revision" => "Blog::Revision",
  }

  def up
    execute <<~SQL
      DROP VIEW IF EXISTS
        discourse_blog_publications,
        discourse_blog_paths,
        discourse_blog_revisions,
        discourse_blog_reviews,
        discourse_blog_review_feedback
    SQL

    # The old code keeps writing these until its app servers restart.
    RENAMED_TYPES.each do |old_type, new_type|
      DB.exec(<<~SQL, old_type:, new_type:)
        UPDATE upload_references old
        SET target_type = :new_type
        WHERE old.target_type = :old_type
          AND NOT EXISTS (
            SELECT 1 FROM upload_references
            WHERE upload_id = old.upload_id AND target_type = :new_type AND target_id = old.target_id
          )
      SQL

      # Anything left duplicates a reference that already uses the new name.
      DB.exec("DELETE FROM upload_references WHERE target_type = :old_type", old_type:)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

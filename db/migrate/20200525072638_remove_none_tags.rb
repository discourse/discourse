# frozen_string_literal: true

class RemoveNoneTags < ActiveRecord::Migration[6.0]
  def up
    none_tag_id = DB.query_single("SELECT id FROM tags WHERE lower(name) = 'none'").first
    if none_tag_id.present?
      [:tag_users, :topic_tags, :category_tag_stats, :category_tags, :tag_group_memberships].each do |table_name|
        execute "DELETE FROM #{table_name} WHERE tag_id = #{none_tag_id}"
      end
      execute "DELETE FROM tags WHERE id = #{none_tag_id} OR target_tag_id = #{none_tag_id}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

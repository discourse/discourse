# frozen_string_literal: true

class InsertNewTopicToCommunitySection < ActiveRecord::Migration[7.0]
  def up
    community_section_query = DB.query <<~SQL
      SELECT id FROM sidebar_sections WHERE section_type = 0
    SQL

    result = DB.query <<~SQL
      INSERT INTO sidebar_urls(name, value, icon, segment, external, created_at, updated_at)
      VALUES ('New Topic', '/new-topic','plus', 0, false, now(), now())
      RETURNING sidebar_urls.id
    SQL

    result = DB.query <<~SQL
      INSERT INTO sidebar_section_links(user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
      SELECT -1, #{result[0].id}, 'SidebarUrl', #{community_section_query.first.id}, MAX(position) + 1, now(), now() FROM sidebar_section_links
      WHERE sidebar_section_id = #{community_section_query.first.id}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

# frozen_string_literal: true

class SystemUserForPublicSections < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL, user_id: Discourse.system_user)
      UPDATE sidebar_sections
      SET user_id = :user_id
      WHERE public IS TRUE
    SQL
    DB.exec(<<~SQL, user_id: Discourse.system_user)
      UPDATE sidebar_section_links
      SET user_id = :user_id
      FROM sidebar_sections
      WHERE sidebar_sections.public IS TRUE
        AND sidebar_section_links.sidebar_section_id = sidebar_sections.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

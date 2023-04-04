# frozen_string_literal: true

class SystemUserForPublicSections < ActiveRecord::Migration[7.0]
  def up
    execute(<<-SQL)
      UPDATE sidebar_sections
      SET user_id = -1
      WHERE public IS TRUE
    SQL
    execute(<<-SQL)
      UPDATE sidebar_section_links
      SET user_id = -1
      FROM sidebar_sections
      WHERE sidebar_sections.public IS TRUE
        AND sidebar_section_links.sidebar_section_id = sidebar_sections.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

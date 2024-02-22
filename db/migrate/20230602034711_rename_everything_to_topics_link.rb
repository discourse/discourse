# frozen_string_literal: true
class RenameEverythingToTopicsLink < ActiveRecord::Migration[7.0]
  def up
    DB.exec <<~SQL
      UPDATE sidebar_urls su1
      SET name = 'Topics'
      FROM sidebar_urls su2
      INNER JOIN sidebar_section_links ON sidebar_section_links.linkable_id = su2.id
      INNER JOIN sidebar_sections ON sidebar_sections.id = sidebar_section_links.sidebar_section_id AND sidebar_sections.section_type = 0
      WHERE su1.id = su2.id AND su2.value = '/latest' AND su2.name = 'Everything'
    SQL
  end

  def down
    DB.exec <<~SQL
      UPDATE sidebar_urls su1
      SET name = 'Everything'
      FROM sidebar_urls su2
      INNER JOIN sidebar_section_links ON sidebar_section_links.linkable_id = su2.id
      INNER JOIN sidebar_sections ON sidebar_sections.id = sidebar_section_links.sidebar_section_id AND sidebar_sections.section_type = 0
      WHERE su1.id = su2.id AND su2.value = '/topics' AND su2.name = 'Topics'
    SQL
  end
end

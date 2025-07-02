# frozen_string_literal: true
class FixCapitalisationInSidebarUrls < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE sidebar_urls
      SET name = CASE
        WHEN name = 'My Messages' THEN 'My messages'
        WHEN name = 'My Posts' THEN 'My posts'
        ELSE name
      END
      WHERE name IN ('My Messages', 'My Posts');
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

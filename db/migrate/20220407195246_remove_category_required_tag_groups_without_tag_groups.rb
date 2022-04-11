# frozen_string_literal: true

class RemoveCategoryRequiredTagGroupsWithoutTagGroups < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE FROM category_required_tag_groups
      WHERE id IN (
        SELECT crtg.id
        FROM category_required_tag_groups crtg
        LEFT OUTER JOIN tag_groups tg ON crtg.tag_group_id = tg.id
        WHERE tg.id IS NULL
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

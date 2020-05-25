# frozen_string_literal: true

class RemoveNoneTags < ActiveRecord::Migration[6.0]
  def up
    none_tag = Tag.find_by(name: "none")
    if none_tag
      none_tag.destroy
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

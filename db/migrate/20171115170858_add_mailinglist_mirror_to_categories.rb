# frozen_string_literal: true

class AddMailinglistMirrorToCategories < ActiveRecord::Migration[5.1]
  def up
    add_column :categories, :mailinglist_mirror, :boolean, default: false, null: false
  end

  def down
    remove_column :categories, :mailinglist_mirror
  end
end

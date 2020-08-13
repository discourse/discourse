# frozen_string_literal: true

class RenameModeratorsCreateCategoriesSetting < ActiveRecord::Migration[6.0]
  def up
    # TODO - do we need to rename old UserHistory log entries too?
    execute "UPDATE site_settings SET name = 'moderators_manage_categories_and_groups' WHERE name = 'moderators_create_categories'"
  end

  def down
    execute "UPDATE site_settings SET name = 'moderators_create_categories' WHERE name = 'moderators_manage_categories_and_groups'"
  end
end

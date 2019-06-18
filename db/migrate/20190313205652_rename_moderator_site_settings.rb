# frozen_string_literal: true

class RenameModeratorSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings SET name = 'moderators_view_emails' WHERE name = 'show_email_on_profile'"
    execute "UPDATE site_settings SET name = 'moderators_create_categories' WHERE name = 'allow_moderators_to_create_categories'"
  end

  def down
    execute "UPDATE site_settings SET name = 'show_email_on_profile' WHERE name = 'moderators_view_emails'"
    execute "UPDATE site_settings SET name = 'allow_moderators_to_create_categories' WHERE name = 'moderators_create_categories'"
  end
end

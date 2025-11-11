# frozen_string_literal: true

class RenameEnableCategoriesSiteSettings < ActiveRecord::Migration[7.0]
  def setting(old, new)
    execute "UPDATE site_settings SET name='#{new}' where name='#{old}'"
  end

  def up
    setting :zendesk_enable_all_categories, :zendesk_autogenerate_all_categories
    setting :zendesk_enabled_categories, :zendesk_autogenerate_categories
  end

  def down
    setting :zendesk_autogenerate_all_categories, :zendesk_enable_all_categories
    setting :zendesk_autogenerate_categories, :zendesk_enabled_categories
  end
end

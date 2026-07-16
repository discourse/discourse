# frozen_string_literal: true

class SeedDefaultHomepageFromTopMenu < ActiveRecord::Migration[8.0]
  # Historically the homepage was implicitly the first item of `top_menu`. The new
  # `default_homepage` setting makes this explicit. To avoid silently changing the
  # homepage for existing sites that reordered `top_menu`, seed `default_homepage`
  # from the current first `top_menu` item.
  #
  # Fresh installs are skipped: they have no `top_menu` row, and the new
  # `default_homepage` default of `latest` already matches the default `top_menu`,
  # so no rows are created on a clean database. Values that aren't valid homepage
  # choices (e.g. legacy category entries) are ignored, as is `latest` (the default).
  def up
    return unless Migration::Helpers.existing_site?

    execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT
        'default_homepage',
        7,
        split_part(split_part(value, '|', 1), ',', 1),
        NOW(),
        NOW()
      FROM site_settings
      WHERE name = 'top_menu'
        AND split_part(split_part(value, '|', 1), ',', 1) IN (
          'new', 'unread', 'unseen', 'top', 'categories', 'read', 'posted', 'bookmarks', 'hot'
        )
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM site_settings WHERE name = 'default_homepage'"
  end
end

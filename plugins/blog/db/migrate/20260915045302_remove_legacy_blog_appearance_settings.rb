# frozen_string_literal: true

# Blog designs own their palette and code now. A site that only ever configured the
# old appearance settings keeps that design as an activated theme, which is how
# readers keep seeing it.
class RemoveLegacyBlogAppearanceSettings < ActiveRecord::Migration[8.0]
  STORE = "discourse-blog-themes"
  THEME_NAME = "Current appearance"

  # Theme field => legacy site setting, with the setting's old default.
  LEGACY_SETTINGS = {
    "accent_color" => %w[discourse_blog_accent_color d64b2a],
    "paper_color" => %w[discourse_blog_paper_color f5f0e6],
    "ink_color" => %w[discourse_blog_ink_color 19382d],
    "css" => ["discourse_blog_custom_css", ""],
    "javascript" => ["discourse_blog_custom_js", ""],
  }.freeze

  # Mirrors the reader's Liquid pages; a missing key means "use the built-in".
  TEMPLATE_FIELDS = %w[
    template_layout
    template_index
    template_article
    template_about
    template_not_found
  ].freeze

  def up
    carry_over_legacy_appearance if Migration::Helpers.existing_site?

    names = LEGACY_SETTINGS.values.map { |setting_name, _| "'#{setting_name}'" }.join(", ")
    execute "DELETE FROM site_settings WHERE name IN (#{names})"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def carry_over_legacy_appearance
    return if theme_exists?

    values = legacy_values
    return if values.all? { |field, value| value == LEGACY_SETTINGS[field][1] }

    theme = theme_for(values)
    insert_row("theme:#{theme["id"]}", theme)
    insert_row("snapshot:#{theme["snapshot"]}", theme)
    insert_row("active", theme)
  end

  def theme_exists?
    DB.query_single(
      "SELECT 1 FROM plugin_store_rows WHERE plugin_name = :store AND key LIKE 'theme:%' LIMIT 1",
      store: STORE,
    ).present?
  end

  def legacy_values
    LEGACY_SETTINGS.to_h do |field, (setting_name, default)|
      # Only customized settings have a row; a missing one still means its default.
      value =
        DB.query_single(
          "SELECT value FROM site_settings WHERE name = :name",
          name: setting_name,
        ).first
      [field, value.nil? ? default : value.to_s]
    end
  end

  def theme_for(values)
    {
      "id" => SecureRandom.uuid,
      "name" => THEME_NAME,
      "revision" => 1,
      "accent_color" => values["accent_color"],
      "paper_color" => values["paper_color"],
      "ink_color" => values["ink_color"],
      "css" => values["css"],
      "javascript" => values["javascript"],
      "source" => nil,
      "locally_modified" => false,
      "snapshot" => SecureRandom.uuid,
    }.merge(TEMPLATE_FIELDS.to_h { |field| [field, ""] })
  end

  def insert_row(key, theme)
    DB.exec(<<~SQL, store: STORE, key: key, value: theme.to_json)
      INSERT INTO plugin_store_rows (plugin_name, key, type_name, value)
      VALUES (:store, :key, 'JSON', :value)
    SQL
  end
end

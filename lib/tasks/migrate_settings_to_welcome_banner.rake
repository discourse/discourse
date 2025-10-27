# frozen_string_literal: true

desc "Migrate settings from Advanced Search Banner to core  welcome banner"
task "themes:migrate_settings_to_welcome_banner" => :environment do
  advanced_search_banners = []

  if ENV["RAILS_DB"].present?
    advanced_search_banners = find_site_settings(ENV["RAILS_DB"])
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      found = find_site_settings(db)
      advanced_search_banners.concat(found.map { |asb| { db: db, asb: asb } })
    end
  end

  if advanced_search_banners.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components were found.\e[0m"
  else
    puts "\n\e[1;36m=== Migration Summary ===\e[0m"
    advanced_search_banners.each do |entry|
      if entry.is_a?(Hash) && entry[:db]
        puts "\nDatabase: \e[1;104m[#{entry[:db]}]\e[0m"
        theme_data = entry[:asb]
        puts "  Theme: #{theme_data[:name]} (ID: #{theme_data[:id]})"
        puts "  Migrated settings: #{theme_data[:migrated_settings]}"
      else
        puts "\n  Theme: #{entry[:name]} (ID: #{entry[:id]})"
        puts "  Migrated settings: #{entry[:migrated_settings]}"
      end
    end
    puts "\n\e[1;32m✓ Settings migration completed!\e[0m"
  end
end

def find_site_settings(db)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"

  advanced_search_banners = []

  puts "  Searching for Advanced Search Banner theme components..."
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(theme: :theme_settings)
    .each do |remote_theme|
      theme = remote_theme.theme

      puts "  \e[1;32m✓ Found: #{theme.name} (ID: #{theme.id})\e[0m"
      puts "\n  Migrating settings..."

      advanced_search_banners << {
        name: theme.name,
        id: theme.id,
        migrated_settings: migrate_theme_settings_to_site_settings(theme.theme_settings),
      }
    end

  advanced_search_banners
end

SETTINGS_MAPPING = {
  "show_on" => {
    site_setting: "welcome_banner_page_visibility",
    value_mapping: {
      "top_menu" => "top_menu_pages",
      "all_pages" => "all_pages",
    },
  },
  "plugin_outlet" => {
    site_setting: "welcome_banner_location",
    value_mapping: {
      "above-main-container" => "above_topic_content",
      "below-site-header" => "below_site_header",
    },
  },
  "background_image_light" => {
    site_setting: "welcome_banner_image",
    value_mapping: nil,
  },
}

def migrate_theme_settings_to_site_settings(theme_settings)
  migrated_count = 0

  theme_settings.each do |ts|
    mapping = SETTINGS_MAPPING[ts.name]
    next unless mapping

    site_setting_name = mapping[:site_setting]
    next if ts.value.blank?

    if mapping[:value_mapping]
      new_value = mapping[:value_mapping][ts.value] || ts.value
    else
      new_value = ts.value.to_i
    end

    begin
      SiteSetting.set_and_log(
        site_setting_name,
        new_value,
        Discourse.system_user,
        "Migrated from the deprecated Advanced Search Banner",
      )

      old_text = "\e[0;31m#{ts.name}: #{ts.value}\e[0m"
      arrow = "\e[0m=>\e[0m"
      new_text = "\e[0;32m#{site_setting_name}: #{new_value}\e[0m"

      puts "    #{old_text} #{arrow} #{new_text}"
      migrated_count += 1
    rescue StandardError => e
      puts "    \e[1;31m✗ Failed to migrate #{ts.name}: #{e.message}\e[0m"
    end
  end

  migrated_count
end

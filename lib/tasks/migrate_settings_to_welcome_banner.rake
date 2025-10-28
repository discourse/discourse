# frozen_string_literal: true

THEME_GIT_URL_SETTINGS = "https://github.com/discourse/discourse-search-banner.git"

desc "Migrate settings from Advanced Search Banner to core welcome banner"
task "themes:advanced_search_banner:migrate_settings_to_welcome_banner" => :environment do
  components = find_all_components_for_settings

  if components.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components found.\e[0m"
    next
  end

  components.each { |entry| process_theme_component_settings(entry[:theme]) }

  puts "\n\e[1;34mTask completed successfully!\e[0m"
end

def find_all_components_for_settings
  if ENV["RAILS_DB"].present?
    db = validate_and_get_db_for_settings(ENV["RAILS_DB"])
    RailsMultisite::ConnectionManagement.establish_connection(db: db)
    wrap_themes_with_db_for_settings(find_components_in_db_for_settings(db), db)
  else
    components = []
    RailsMultisite::ConnectionManagement.each_connection do |db|
      components.concat(
        wrap_themes_with_db_for_settings(find_components_in_db_for_settings(db), db),
      )
    end
    components
  end
end

def validate_and_get_db_for_settings(db)
  return db if RailsMultisite::ConnectionManagement.has_db?(db)

  default_db = RailsMultisite::ConnectionManagement::DEFAULT
  puts "\e[31mDatabase \e[1;101m[#{db}]\e[0m \e[31mnot found.\e[0m"
  puts "Using default database instead: \e[1;104m[#{default_db}]\e[0m\n\n"
  default_db
end

def wrap_themes_with_db_for_settings(themes, db)
  themes.map { |theme| { db: db, theme: theme } }
end

def find_components_in_db_for_settings(db)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"
  puts "  Searching for Advanced Search Banner components..."

  themes =
    RemoteTheme
      .where(remote_url: THEME_GIT_URL_SETTINGS)
      .includes(theme: :theme_settings)
      .map(&:theme)

  themes.each { |theme| puts "  \e[1;34mFound: #{theme_identifier_for_settings(theme)}" }
  themes
end

def theme_identifier_for_settings(theme)
  "\e[1m#{theme.name} (ID: #{theme.id})\e[0m"
end

def process_theme_component_settings(theme)
  puts "\n  Migrating settings for #{theme_identifier_for_settings(theme)}..."
  migrated_count = migrate_theme_settings_to_site_settings(theme.theme_settings)
  puts "  \e[1;32m✓ Migrated #{migrated_count} setting#{"s" if migrated_count != 1}\e[0m"
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

      puts "    - #{old_text} #{arrow} #{new_text}"
      migrated_count += 1
    rescue StandardError => e
      puts "    \e[1;31m✗ Failed to migrate #{ts.name}: #{e.message}\e[0m"
    end
  end

  migrated_count
end

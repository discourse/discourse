# frozen_string_literal: true

THEME_GIT_URL = "https://github.com/discourse/discourse-search-banner.git" unless defined?(
  THEME_GIT_URL
)
REQUIRED_TRANSLATION_KEYS = %w[search_banner.headline search_banner.subhead] unless defined?(
  REQUIRED_TRANSLATION_KEYS
)

desc "Migrate settings from Advanced Search Banner to core welcome banner"
task "themes:advanced_search_banner:migrate_settings_to_welcome_banner" => :environment do
  components = find_all_components([:theme_settings])

  if components.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components found\e[0m"
    next
  end

  components.each { |entry| process_theme_component_settings(entry[:theme]) }
end

desc "Migrate translations from Advanced Search Banner to core welcome banner"
task "themes:advanced_search_banner:migrate_translations_to_welcome_banner" => :environment do
  components = find_all_components([:theme_translation_overrides])

  if components.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components found\e[0m"
    next
  end

  components.each { |entry| process_theme_component_translations(entry[:theme]) }
end

desc "Exclude and disable Advanced Search Banner theme component"
task "themes:advanced_search_banner:exclude_and_disable" => :environment do
  components = find_all_components

  if components.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components found\e[0m"
    next
  end

  components.each { |entry| process_theme_component(entry[:theme]) }
end

# Common helper methods
def find_all_components(includes = [])
  if ENV["RAILS_DB"].present?
    db = validate_and_get_db(ENV["RAILS_DB"])
    RailsMultisite::ConnectionManagement.establish_connection(db: db)
    wrap_themes_with_db(find_components_in_db(db, includes), db)
  else
    components = []
    RailsMultisite::ConnectionManagement.each_connection do |db|
      components.concat(wrap_themes_with_db(find_components_in_db(db, includes), db))
    end
    components
  end
end

def validate_and_get_db(db)
  return db if RailsMultisite::ConnectionManagement.has_db?(db)

  default_db = RailsMultisite::ConnectionManagement::DEFAULT
  puts "\e[31m✗ Database \e[1;101m[#{db}]\e[0m \e[31mnot found\e[0m"
  puts "Using default database instead: \e[1;104m[#{default_db}]\e[0m\n\n"
  default_db
end

def wrap_themes_with_db(themes, db)
  themes.map { |theme| { db: db, theme: theme } }
end

def find_components_in_db(db, additional_includes)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"
  puts "  Searching for Advanced Search Banner components..."

  includes = [{ parent_theme_relation: :parent_theme }] + Array(additional_includes)
  themes = RemoteTheme.where(remote_url: THEME_GIT_URL).includes(theme: includes).map(&:theme)

  themes.each { |theme| puts "  \e[1;34mFound: #{theme_identifier(theme)}" }
  themes
end

def theme_identifier(theme)
  "\e[1m#{theme.name} (ID: #{theme.id})\e[0m"
end

def not_included_in_any_theme?(theme)
  return false if theme.parent_theme_relation.exists?

  puts "  \e[33m#{theme_identifier(theme)} is not included in any of your themes. Skipping\e[0m"
  true
end

# Settings migration methods
unless defined?(SETTINGS_MAPPING)
  SETTINGS_MAPPING = {
    "show_on" => {
      site_setting: "welcome_banner_page_visibility",
      value_mapping: {
        "top_menu" => "top_menu_pages",
        "all" => "all_pages",
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
end

def process_theme_component_settings(theme)
  return if not_included_in_any_theme?(theme)
  migration_errors = []

  puts "\n  Migrating settings for #{theme_identifier(theme)}..."
  migrated_count = migrate_theme_settings_to_site_settings(theme.theme_settings, migration_errors)
  if migrated_count == theme.theme_settings.size
    puts "  \e[1;32m✓ Migrated #{migrated_count} setting#{"s" if migrated_count != 1}\e[0m"
  else
    puts "  \e[33mMigrated #{migrated_count} out of #{theme.theme_settings.size} setting#{"s" if theme.theme_settings.size != 1}\e[0m"
  end

  if migration_errors.any?
    puts "\n\e[1;31mMigration completed with errors\e[0m"
  else
    puts "\n\e[1;34mMigration completed successfully!\e[0m"
  end
end

def migrate_theme_settings_to_site_settings(theme_settings, errors)
  migrated_count = 0

  theme_settings.each do |ts|
    mapping = SETTINGS_MAPPING[ts.name]
    next unless mapping

    site_setting_name = mapping[:site_setting]
    if ts.value.blank?
      puts "    - skipping '#{ts.name}' as it has no value"
      next
    end

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
      errors << e
      puts "    \e[31m- failed to migrate '#{ts.name}': \e[1m#{e.message}\e[0m"
    end
  end

  migrated_count
end

# Translations migration methods
def process_theme_component_translations(theme)
  return if not_included_in_any_theme?(theme)

  puts "\n  Migrating translation overrides for #{theme_identifier(theme)}..."

  migrated_count = 0

  if theme.theme_translation_overrides.any?
    processed_keys_by_locale = Hash.new { |h, k| h[k] = Set.new }

    theme.theme_translation_overrides.each do |override|
      count =
        migrate_translations(
          locale: override.locale,
          key: override.translation_key,
          value: override.value,
        )
      migrated_count += count

      processed_keys_by_locale[override.locale].add(override.translation_key)
    end

    shown = false
    processed_keys_by_locale.each do |locale, processed_keys|
      missing_keys = REQUIRED_TRANSLATION_KEYS - processed_keys.to_a

      if missing_keys.any?
        unless shown
          puts "  Migrating Advanced Search Banner's default translations..."
          shown = true
        end

        missing_keys.each do |missing_key|
          count = migrate_translations(locale: locale, key: missing_key)
          migrated_count += count
        end
      end
    end
  else
    puts "  \e[33m✗ No translation overrides found\e[0m"
    puts "  Migrating Advanced Search Banner's default translations..."
    REQUIRED_TRANSLATION_KEYS.each do |required_key|
      count = migrate_translations(key: required_key)
      migrated_count += count
    end
  end

  puts "  \e[1;32m✓ Migrated #{migrated_count} translation#{"s" if migrated_count != 1}\e[0m"
  puts "\n\e[1;34mMigration completed successfully!\e[0m"
end

def migrate_translations(locale: "en", key:, value: nil)
  default_translations = {
    "js.welcome_banner.header.anonymous_members" => "Welcome to our community",
    "js.welcome_banner.header.logged_in_members" => "Welcome to our community",
    "js.welcome_banner.subheader.anonymous_members" =>
      "We're happy to have you here. If you need help, please search before you post.",
    "js.welcome_banner.subheader.logged_in_members" =>
      "We're happy to have you here. If you need help, please search before you post.",
  }
  mapped_keys = map_translation_keys(key)

  # Print the value once before processing all keys
  first_key = mapped_keys.first
  new_value = value || default_translations[first_key]
  puts "    \e[1;32m✓\e[0m \e[1;94m\"#{new_value}\"\e[0m"

  mapped_keys.each do |new_key|
    actual_value = value || default_translations[new_key]
    TranslationOverride.upsert!(locale, new_key, actual_value)

    old_text = "\e[0;31m#{key}\e[0m"
    arrow = "\e[0m=>\e[0m"
    new_text = "\e[0;32m#{locale}.#{new_key}\e[0m"

    puts "      - #{old_text} #{arrow} #{new_text}"
  end

  mapped_keys.count
end

def map_translation_keys(translation_key)
  translations_mapping = {
    "search_banner.headline" => %w[
      js.welcome_banner.header.anonymous_members
      js.welcome_banner.header.logged_in_members
    ],
    "search_banner.subhead" => %w[
      js.welcome_banner.subheader.anonymous_members
      js.welcome_banner.subheader.logged_in_members
    ],
    "search_banner.search_button_text" => ["js.welcome_banner.search_placeholder"],
  }

  translations_mapping[translation_key] || []
end

# Exclude and disable methods
def process_theme_component(theme)
  enable_welcome_banner(theme)
  exclude_theme_component(theme)
  disable_theme_component(theme)

  puts "\n\e[1;34mTask completed successfully!\e[0m"
end

def enable_welcome_banner(theme)
  puts "\n  Executing enable core welcome banner step... (1/3)"
  if !theme.enabled
    puts "  \e[33m#{theme_identifier(theme)} is disabled, thus no need to enable core welcome banner. Skipping\e[0m"
    return
  end
  return unless theme.enabled

  return if not_included_in_any_theme?(theme)

  puts "  Enabling \e[1mcore welcome banner\e[0m for..."
  enabled_count = 0

  theme.parent_theme_relation.each do |relation|
    parent_theme = relation.parent_theme
    site_setting =
      ThemeSiteSetting.find_by(theme_id: parent_theme.id, name: "enable_welcome_banner")

    next if site_setting.nil?

    if site_setting.value == "f"
      Themes::ThemeSiteSettingManager.call(
        params: {
          theme_id: parent_theme.id,
          name: "enable_welcome_banner",
          value: true,
        },
        guardian: Discourse.system_user.guardian,
      )
      puts "    - #{parent_theme.name} (ID: #{parent_theme.id}) \e[32m- enabled\e[0m"
      enabled_count += 1
    else
      puts "    - #{parent_theme.name} (ID: #{parent_theme.id}) \e[33m- it was already enabled. Skipping\e[0m"
    end
  end

  puts "  \e[1;32m✓ Enabled for #{enabled_count} theme#{"s" unless enabled_count == 1}\e[0m"
end

def exclude_theme_component(theme)
  puts "\n  Executing exclude step... (2/3)"
  return if not_included_in_any_theme?(theme)

  parent_relations = theme.parent_theme_relation.to_a
  total_relations = parent_relations.size
  parent_names = parent_relations.map { |r| "#{r.parent_theme.name} (ID: #{r.parent_theme_id})" }

  puts "  Excluding #{theme_identifier(theme)} from:"
  puts "    - #{parent_names.join("\n    - ")}"

  theme.parent_theme_ids = []
  theme.save!
  puts "  \e[1;32m✓ Excluded from #{total_relations} theme#{"s" if total_relations > 1}\e[0m"
end

def disable_theme_component(theme)
  puts "\n  Executing disable component step... (3/3)"
  if !theme.enabled
    puts "  \e[33m#{theme_identifier(theme)} was already disabled. Skipping\e[0m"
    return
  end

  puts "  Disabling #{theme_identifier(theme)}..."
  theme.update!(enabled: false)
  StaffActionLogger.new(Discourse.system_user).log_theme_component_disabled(theme)
  puts "  \e[1;32m✓ Disabled\e[0m"
end

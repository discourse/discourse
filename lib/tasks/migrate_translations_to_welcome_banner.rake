# frozen_string_literal: true

THEME_GIT_URL_TRANSLATIONS = "https://github.com/discourse/discourse-search-banner.git"
REQUIRED_TRANSLATION_KEYS = %w[search_banner.headline search_banner.subhead]

desc "Migrate translations from Advanced Search Banner to core welcome banner"
task "themes:advanced_search_banner:migrate_translations_to_welcome_banner" => :environment do
  components = find_all_components_for_translations

  if components.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components found.\e[0m"
    next
  end

  components.each { |entry| process_theme_component_translations(entry[:theme]) }

  puts "\n\e[1;34mTask completed successfully!\e[0m"
end

def find_all_components_for_translations
  if ENV["RAILS_DB"].present?
    db = validate_and_get_db_for_translations(ENV["RAILS_DB"])
    RailsMultisite::ConnectionManagement.establish_connection(db: db)
    wrap_themes_with_db_for_translations(find_components_in_db_for_translations(db), db)
  else
    components = []
    RailsMultisite::ConnectionManagement.each_connection do |db|
      components.concat(
        wrap_themes_with_db_for_translations(find_components_in_db_for_translations(db), db),
      )
    end
    components
  end
end

def validate_and_get_db_for_translations(db)
  return db if RailsMultisite::ConnectionManagement.has_db?(db)

  default_db = RailsMultisite::ConnectionManagement::DEFAULT
  puts "\e[31mDatabase \e[1;101m[#{db}]\e[0m \e[31mnot found.\e[0m"
  puts "Using default database instead: \e[1;104m[#{default_db}]\e[0m\n\n"
  default_db
end

def wrap_themes_with_db_for_translations(themes, db)
  themes.map { |theme| { db: db, theme: theme } }
end

def find_components_in_db_for_translations(db)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"
  puts "  Searching for Advanced Search Banner components..."

  themes =
    RemoteTheme
      .where(remote_url: THEME_GIT_URL_TRANSLATIONS)
      .includes(theme: :theme_translation_overrides)
      .map(&:theme)

  themes.each { |theme| puts "  \e[1;34mFound: #{theme_identifier_for_translations(theme)}" }
  themes
end

def theme_identifier_for_translations(theme)
  "\e[1m#{theme.name} (ID: #{theme.id})\e[0m"
end

def process_theme_component_translations(theme)
  puts "\n  Migrating translation overrides for #{theme_identifier_for_translations(theme)}..."

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
    puts "  ✗ No translation overrides found. Migrating Advanced Search Banner's default translations..."
    REQUIRED_TRANSLATION_KEYS.each do |required_key|
      count = migrate_translations(key: required_key)
      migrated_count += count
    end
  end

  puts "  \e[1;32m✓ Migrated #{migrated_count} translation#{"s" if migrated_count != 1}\e[0m"
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

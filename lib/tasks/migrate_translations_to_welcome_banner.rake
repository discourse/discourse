# frozen_string_literal: true

desc "Migrate translations from Advanced Search Banner to core  welcome banner"
task "themes:migrate_translations_to_welcome_banner" => :environment do
  advanced_search_banners = []

  if ENV["RAILS_DB"].present?
    advanced_search_banners = find_advanced_search_banners(ENV["RAILS_DB"])
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      found = find_advanced_search_banners(db)
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
        puts "  Migrated translations: #{theme_data[:migrated_translations]}"
      else
        puts "\n  Theme: #{entry[:name]} (ID: #{entry[:id]})"
        puts "  Migrated translations: #{entry[:migrated_translations]}"
      end
    end
    puts "\n\e[1;32m✓ Translations migration completed!\e[0m"
  end
end

def find_advanced_search_banners(db)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"

  required_keys = %w[search_banner.headline search_banner.subhead]
  advanced_search_banners = []

  puts "  Searching for Advanced Search Banner theme components..."
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(theme: :theme_translation_overrides)
    .each do |remote_theme|
      theme = remote_theme.theme

      puts "  \e[1;32m✓ Found: #{theme.name} (ID: #{theme.id})\e[0m"
      puts "\n  Migrating translation overrides..."

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

          # override.destroy!
          puts "    \e[0;93m● Removing old override: #{override.locale}.#{override.translation_key}\e[0m\n\n"
        end

        shown = false
        processed_keys_by_locale.each do |locale, processed_keys|
          missing_keys = required_keys - processed_keys.to_a

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
        required_keys.each do |required_key|
          count = migrate_translations(key: required_key)
          migrated_count += count
        end
      end

      advanced_search_banners << {
        name: theme.name,
        id: theme.id,
        migrated_translations: migrated_count,
      }
    end

  advanced_search_banners
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

    puts "      #{old_text} #{arrow} #{new_text}"
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

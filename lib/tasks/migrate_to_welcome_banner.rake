# frozen_string_literal: true

desc "Migrate from Advanced search banner theme component to core Welcome banner"
task "themes:migrate_to_welcome_banner" => :environment do
  advanced_search_banners = []

  if ENV["RAILS_DB"].present?
    advanced_search_banners = find_advanced_search_banners(ENV["RAILS_DB"])
  else
    RailsMultisite::ConnectionManagement.all_dbs.each do |db|
      RailsMultisite::ConnectionManagement.with_connection(db) do
        found = find_advanced_search_banners(db)
        advanced_search_banners.concat(found.map { |asb| { db: db, asb: asb } })
      end
    end
  end

  if advanced_search_banners.empty?
    puts "No Advanced search banner theme components were found."
  else
    puts "Migration completed!"
    # puts advanced_search_banners
    # advanced_search_banners.each do |entry|
    #   if entry.is_a?(Hash)
    #     puts "Database: [#{entry[:db]}]\nTheme: #{entry[:theme][:name]}\nTheme ID: #{entry[:theme][:id]}\nTheme status: #{entry[:theme][:status]}"
    #   else
    #     puts "Theme: #{entry[:name]}\nTheme ID: #{entry[:id]}\nTheme status: #{entry[:status]}"
    #   end
    # end
  end
end

def find_advanced_search_banners(db)
  puts "Accessing database: [#{db}]"

  required_keys = %w[search_banner.headline search_banner.subhead]
  advanced_search_banners = []

  puts "  Searching for Advanced Search Banner theme components..."
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(theme: :theme_translation_overrides)
    .each do |remote_theme|
      theme = remote_theme.theme

      puts "  ✓ Found: #{theme.name} (ID: #{theme.id})"
      puts "  Searching for translation overrides..."

      if theme.theme_translation_overrides.any?
        puts "  Migrating translation overrides..."

        processed_keys_by_locale = Hash.new { |h, k| h[k] = Set.new }

        theme.theme_translation_overrides.each do |override|
          migrate_translations(
            locale: override.locale,
            key: override.translation_key,
            value: override.value,
          )

          processed_keys_by_locale[override.locale].add(override.translation_key)

          # override.destroy!
          puts "    ● Deleted old override: #{override.locale}.#{override.translation_key}"
        end

        shown = false
        processed_keys_by_locale.each do |locale, processed_keys|
          missing_keys = required_keys - processed_keys.to_a

          if missing_keys.any?
            unless shown
              puts "  Migrating to default translations..."
              shown = true
            end

            missing_keys.each do |missing_key|
              migrate_translations(locale: locale, key: missing_key)
            end
          end
        end
      else
        puts "  ✗ No translation overrides found. Migrating to default translations..."
        required_keys.each { |required_key| migrate_translations(key: required_key) }
      end
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
  mapped_keys.each do |new_key|
    new_value = value || default_translations[new_key]
    TranslationOverride.upsert!(locale, new_key, new_value)
    puts "    ✓ Migrated to: '#{locale}.#{new_key}' = '#{new_value}'"
  end
end

def map_translation_keys(translation_key)
  translation_mappings = {
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

  translation_mappings[translation_key] || []
end

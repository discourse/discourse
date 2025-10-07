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

  advanced_search_banners = []

  puts "  Searching for Advanced Search Banner theme components..."
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(theme: :theme_translation_overrides)
    .each do |remote_theme|
      theme = remote_theme.theme

      puts "  ✓ Found theme component: #{theme.name} (ID: #{theme.id})"
      puts "  Searching for translation overrides..."

      if theme.theme_translation_overrides.any?
        puts "  Migrating translation overrides..."
        theme.theme_translation_overrides.each do |override|
          mapped_keys = map_translation_keys(override.translation_key)

          mapped_keys.each do |new_key|
            TranslationOverride.upsert!(override.locale, new_key, override.value)
            puts "    ✓ Migrated to: '#{override.locale}.#{new_key}' = '#{override.value}'"
          end

          # override.destroy!
          puts "    ● Deleted old override: #{override.locale}.#{override.translation_key}"
        end
      else
        puts "  ✗ No translation overrides found. Default translations will be used."
      end
    end

  advanced_search_banners
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

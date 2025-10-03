# frozen_string_literal: true

desc "Migrate from Advanced search banner theme component to core Welcome banner"
task "themes:migrate_to_welcome_banner" => :environment do
  advanced_search_banners = []

  if ENV["RAILS_DB"].present?
    advanced_search_banners = find_advanced_search_banners(ENV["RAILS_DB"])
  else
    RailsMultisite::ConnectionManagement.all_dbs.each do |db|
      puts "Accessing database: [#{db}]"

      RailsMultisite::ConnectionManagement.with_connection(db) do
        found = find_advanced_search_banners
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

def find_advanced_search_banners
  advanced_search_banners = []

  puts "  Searching for Advanced Search Banner theme components..."
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(theme: :theme_translation_overrides)
    .each do |remote_theme|
      theme = remote_theme.theme
      next unless theme&.component? # Only process component themes

      puts "  ✓ Found theme component: #{theme.name} (ID: #{theme.id})"
      puts "  Searching for translation overrides..."

      overrides =
        theme.theme_translation_overrides.map do |override|
          {
            locale: override.locale,
            translation_key: override.translation_key,
            value: override.value,
          }
        end

      if overrides.any?
        puts "  Migrating translation overrides..."
        overrides.each do |override|
          mapped_keys = map_search_banner_to_welcome_banner(override[:translation_key])

          if mapped_keys.any?
            mapped_keys.each do |new_key|
              TranslationOverride.upsert!(override[:locale], new_key, override[:value])
              puts "    ✓ Migrated to: '#{override[:locale]}.#{new_key}' = '#{override[:value]}'"
            end
          else
            puts "    ✗ No mapping found for: '#{override[:translation_key]}'"
          end
        end
      else
        puts "  ✗ No translation overrides found. Default translations will be used."
      end

      # next
      # result = deprecate_theme(theme)
      result = {
        id: theme.id,
        name: theme.name,
        status: "Found with #{overrides.count} translation overrides",
        overrides: overrides,
      }
      advanced_search_banners << result if result
    end

  advanced_search_banners
end

def map_search_banner_to_welcome_banner(translation_key)
  translation_mappings = {
    "search_banner.headline" => %w[
      js.welcome_banner.header.anonymous_members
      js.welcome_banner.header.logged_in_members
    ],
    "search_banner.subhead" => %w[
      js.welcome_banner.subheader.anonymous_members
      js.welcome_banner.subheader.logged_in_members
    ],
    "search_banner.search_button_text" => "js.welcome_banner.search_placeholder",
  }

  mapping = translation_mappings[translation_key]
  return [] unless mapping

  Array(mapping)
end

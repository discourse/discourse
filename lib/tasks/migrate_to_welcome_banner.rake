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
            puts "    × No mapping found for: '#{override[:translation_key]}'"
          end
        end
      else
        puts "  × No translation overrides found. Default translations will be used."
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

# def deprecate_theme(theme)
#   puts "  Found: #{theme.name} (ID: #{theme.id})"

#   # Migrate translations before deprecating
#   migrate_search_banner_translations(theme)

#   # Return a result object - currently just reporting what we found
#   { id: theme.id, name: theme.name, status: "Found (deprecation logic commented out)" }

#   begin
#     theme.update!(enabled: false, user_selectable: false, auto_update: false)

#     # Add a deprecation notice to the theme's description if it doesn't already exist
#     current_about = theme.about || {}
#     deprecation_notice =
#       "[DEPRECATED] This theme component has been deprecated. Please use the built-in search functionality or consider alternative search solutions."

#     unless current_about["description"]&.include?("[DEPRECATED]")
#       current_about["description"] = if current_about["description"].present?
#         "#{deprecation_notice}\n\n#{current_about["description"]}"
#       else
#         deprecation_notice
#       end

#       theme.update!(about: current_about)
#     end

#     puts "    ✓ Disabled and marked as deprecated"
#     { id: theme.id, name: theme.name, status: "Successfully deprecated" }
#   rescue => e
#     puts "    ✗ Failed to deprecate: #{e.message}"
#     { id: theme.id, name: theme.name, status: "Failed to deprecate: #{e.message}" }
#   end
# end

def migrate_search_banner_translations(theme)
  puts "    Migrating translations..."

  # Translation key mappings from search_banner to welcome_banner
  # Each source key can map to multiple destination keys (using arrays)
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

  migrated_count = 0

  # Check for theme translation overrides first
  theme.theme_translation_overrides.find_each do |override|
    mapping_keys = translation_mappings[override.translation_key]
    if mapping_keys
      Array(mapping_keys).each do |mapping_key|
        puts "      Migrating override: #{override.translation_key} (#{override.locale}) -> #{mapping_key}"
        create_welcome_banner_translation(mapping_key, override.value, override.locale)
        migrated_count += 1
      end
    end
  end

  # Also check the git repository for default translations
  if migrated_count == 0
    puts "      No theme overrides found, checking git repository defaults..."
    migrate_from_git_repository(translation_mappings)
  end

  puts "      Migration completed. #{migrated_count} translations migrated."
end

# def migrate_from_git_repository(translation_mappings)
#   repo_path = "/Users/yuriy/Projects/discourse-search-banner/locales/en.yml"

#   if File.exist?(repo_path)
#     begin
#       require "yaml"
#       translations = YAML.load_file(repo_path)

#       if translations && translations["en"] && translations["en"]["search_banner"]
#         search_banner_translations = translations["en"]["search_banner"]

#         translation_mappings.each do |search_key, welcome_key|
#           # Extract the last part of the key (e.g., "headline" from "search_banner.headline")
#           value_key = search_key.split(".").last
#           value = search_banner_translations[value_key]

#           if value && !value.empty?
#             puts "        Migrating from repo: #{search_key} -> #{welcome_key}: '#{value}'"
#             create_welcome_banner_translation(welcome_key, value, "en")
#           end
#         end
#       end
#     rescue => e
#       puts "        Error reading git repository translations: #{e.message}"
#     end
#   else
#     puts "        Git repository not found at #{repo_path}"
#   end
# end

def create_welcome_banner_translation(key_path, value, locale = "en")
  # Skip empty values
  return if value.blank?

  # Always use translation overrides for theme migration
  begin
    translation_override = TranslationOverride.upsert!(locale, key_path, value)
    puts "        ✓ Created override: #{locale}.#{key_path} = '#{value}'"
    translation_override
  rescue => e
    puts "        ✗ Failed to create #{locale}.#{key_path}: #{e.message}"
    nil
  end
end

def update_client_locale_file(key_path, value)
  locale_file_path = Rails.root.join("config/locales/client.en.yml")

  begin
    # Load the existing YAML file
    content = YAML.load_file(locale_file_path)

    # Navigate to the nested key and set the value
    # key_path is like "js.welcome_banner.header.anonymous_members"
    # We need to split it and navigate the hash structure
    keys = key_path.split(".")
    current_level = content["en"]

    # Navigate to the parent of the final key
    keys[0..-2].each do |key|
      current_level[key] ||= {}
      current_level = current_level[key]
    end

    # Set the final value
    final_key = keys.last
    current_level[final_key] = value

    # Write back to file with proper YAML formatting
    File.write(locale_file_path, YAML.dump(content))

    puts "        ✓ Updated client.en.yml: #{key_path} = '#{value}'"
  rescue => e
    puts "        ✗ Failed to update client.en.yml for #{key_path}: #{e.message}"
  end
end

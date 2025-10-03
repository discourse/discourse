# frozen_string_literal: true

desc "Deprecate Advanced Search Banner theme component"
task "themes:deprecate_advanced_search_banner" => :environment do
  puts "Deprecating Advanced Search Banner theme component..."

  search_banner_themes = []

  if ENV["RAILS_DB"].present?
    search_banner_themes = find_and_deprecate_search_banner_themes
  else
    RailsMultisite::ConnectionManagement.all_dbs.each do |db|
      RailsMultisite::ConnectionManagement.with_connection(db) do
        puts "[#{db}] Searching for Advanced Search Banner themes..."
        found_themes = find_and_deprecate_search_banner_themes
        search_banner_themes.concat(found_themes.map { |theme| { db: db, theme: theme } })
      end
    end
  end

  if search_banner_themes.empty?
    puts "No Advanced Search Banner themes found to deprecate."
  else
    puts "Deprecation completed. Summary:"
    search_banner_themes.each do |entry|
      if entry.is_a?(Hash)
        puts "Database: [#{entry[:db]}]\nTheme: #{entry[:theme][:name]}\nTheme ID: #{entry[:theme][:id]}\nTheme status: #{entry[:theme][:status]}"
      else
        puts "Theme: #{entry[:name]}\nTheme ID: #{entry[:id]}\nTheme status: #{entry[:status]}"
      end
    end
  end
end

def find_and_deprecate_search_banner_themes
  deprecated_themes = []

  # Search for discourse-search-banner themes (handles both .git and non-.git URLs)
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(:theme)
    .each do |remote_theme|
      theme = remote_theme.theme
      next unless theme&.component? # Only process component themes

      puts "  Found theme: #{theme.name} (ID: #{theme.id})"

      # Get translation overrides for this theme
      overrides = get_theme_translation_overrides(theme.id)
      puts "    Translation overrides found: #{overrides.count}"

      # Display the overrides
      if overrides.any?
        overrides.each do |override|
          puts "      #{override[:locale]}.#{override[:translation_key]} = '#{override[:value]}'"
        end
      else
        puts "      No translation overrides found for this theme"
      end

      # result = deprecate_theme(theme)
      result = {
        id: theme.id,
        name: theme.name,
        status: "Found with #{overrides.count} translation overrides",
        overrides: overrides,
      }
      deprecated_themes << result if result
    end

  deprecated_themes
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

def get_theme_translation_overrides(theme_id)
  # Retrieve all translation overrides for the specified theme
  # Returns an array of hashes with translation_key, value, and locale

  theme = Theme.find_by(id: theme_id)
  return [] unless theme

  overrides = []

  theme.theme_translation_overrides.find_each do |override|
    overrides << {
      translation_key: override.translation_key,
      value: override.value,
      locale: override.locale,
    }
  end

  overrides
end

# def migrate_search_banner_translations(theme)
#   puts "    Migrating translations from Advanced Search Banner to Welcome Banner..."

#   # Translation key mappings from search_banner to welcome_banner
#   # Each source key can map to multiple destination keys (using arrays)
#   translation_mappings = {
#     "search_banner.headline" => %w[
#       js.welcome_banner.header.anonymous_members
#       js.welcome_banner.header.logged_in_members
#     ],
#     "search_banner.subhead" => %w[
#       js.welcome_banner.subheader.anonymous_members
#       js.welcome_banner.subheader.logged_in_members
#     ],
#     "search_banner.search_button_text" => "js.welcome_banner.search_placeholder",
#   }

#   migrated_count = 0

#   # Check for theme translation overrides first
#   theme.theme_translation_overrides.find_each do |override|
#     mapping_keys = translation_mappings[override.translation_key]
#     if mapping_keys
#       Array(mapping_keys).each do |mapping_key|
#         puts "      Migrating override: #{override.translation_key} (#{override.locale}) -> #{mapping_key}"
#         create_welcome_banner_translation(mapping_key, override.value, override.locale)
#         migrated_count += 1
#       end
#     end
#   end

#   # Also check the git repository for default translations
#   if migrated_count == 0
#     puts "      No theme overrides found, checking git repository defaults..."
#     migrate_from_git_repository(translation_mappings)
#   end

#   puts "      Migration completed. #{migrated_count} translations migrated."
# end

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

  if locale == "en"
    # For English locale, update the client.en.yml file directly
    update_client_locale_file(key_path, value)
  else
    # For other locales, use translation overrides
    begin
      translation_override = TranslationOverride.upsert!(locale, key_path, value)
      puts "        ✓ Created override: #{locale}.#{key_path} = '#{value}'"
      translation_override
    rescue => e
      puts "        ✗ Failed to create #{locale}.#{key_path}: #{e.message}"
      nil
    end
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

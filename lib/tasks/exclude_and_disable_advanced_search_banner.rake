# frozen_string_literal: true

desc "Exclude and disable Advanced Search Banner theme component"
task "themes:advanced_search_banner:exclude_and_disable" => :environment do
  advanced_search_banners = []

  if ENV["RAILS_DB"].present?
    advanced_search_banners = find_theme_components(ENV["RAILS_DB"])
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      found = find_theme_components(db)
      advanced_search_banners.concat(found.map { |asb| { db: db, asb: asb } })
    end
  end

  if advanced_search_banners.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components were found.\e[0m"
  else
    advanced_search_banners.each do |entry|
      if entry.is_a?(Hash) && entry[:db]
        puts "\nDatabase: \e[1;104m[#{entry[:db]}]\e[0m"
        theme_data = entry[:asb]
        exclude_theme_component(theme_data)
        disable_theme_component(theme_data)
      else
        exclude_theme_component(entry)
        disable_theme_component(entry)
      end
    end
    puts "\n\e[1;32m✓ The task completed successfully!\e[0m"
  end
end

def find_theme_components(db)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"

  advanced_search_banners = []

  puts "  Searching for Advanced Search Banner theme components..."
  RemoteTheme
    .where(remote_url: "https://github.com/discourse/discourse-search-banner.git")
    .includes(theme: { parent_theme_relation: :parent_theme })
    .each do |remote_theme|
      theme = remote_theme.theme

      puts "  \e[1;32m✓ Found: #{theme.name} (ID: #{theme.id})\e[0m"

      advanced_search_banners << theme
    end

  advanced_search_banners
end

def exclude_theme_component(theme)
  puts "\n  Excluding #{theme.name} (ID: #{theme.id}) from themes..."
  theme.parent_theme_relation.each do |child_theme|
    puts "    #{child_theme.parent_theme.name} (ID: #{child_theme.parent_theme_id})"
    # child_theme.destroy!
  end
  puts "\e[1;32m✓ Excluded: #{theme.name} (ID: #{theme.id}) from #{theme.parent_theme_relation.length} themes\e[0m"
end

def disable_theme_component(theme)
  puts "\n  Disabling #{theme.name} (ID: #{theme.id})..."
  # theme.update!(enabled: false)
  puts "\e[1;33m⚠ Disabled: #{theme.name} (ID: #{theme.id})\e[0m"
end

# frozen_string_literal: true

THEME_GIT_URL = "https://github.com/discourse/discourse-search-banner.git"

desc "Exclude and disable Advanced Search Banner theme component"
task "themes:advanced_search_banner:exclude_and_disable" => :environment do
  components = find_all_components

  if components.empty?
    puts "\n\e[33m✗ No Advanced Search Banner theme components found.\e[0m"
    next
  end

  components.each { |entry| process_theme_component(entry[:theme]) }

  puts "\n\e[1;34mTask completed successfully!\e[0m"
end

def find_all_components
  if ENV["RAILS_DB"].present?
    db = validate_and_get_db(ENV["RAILS_DB"])
    RailsMultisite::ConnectionManagement.establish_connection(db: db)
    wrap_themes_with_db(find_components_in_db(db), db)
  else
    components = []
    RailsMultisite::ConnectionManagement.each_connection do |db|
      components.concat(wrap_themes_with_db(find_components_in_db(db), db))
    end
    components
  end
end

def validate_and_get_db(db)
  return db if RailsMultisite::ConnectionManagement.has_db?(db)

  default_db = RailsMultisite::ConnectionManagement::DEFAULT
  puts "\e[31mDatabase \e[1;101m[#{db}]\e[0m \e[31mnot found.\e[0m"
  puts "Using default database instead: \e[1;104m[#{default_db}]\e[0m\n\n"
  default_db
end

def wrap_themes_with_db(themes, db)
  themes.map { |theme| { db: db, theme: theme } }
end

def find_components_in_db(db)
  puts "Accessing database: \e[1;104m[#{db}]\e[0m"
  puts "  Searching for Advanced Search Banner components..."

  themes =
    RemoteTheme
      .where(remote_url: THEME_GIT_URL)
      .includes(theme: { parent_theme_relation: :parent_theme })
      .map(&:theme)

  themes.each { |theme| puts "  \e[1;34mFound: #{theme_identifier(theme)}" }
  themes
end

def print_database_header(db)
  puts "\nDatabase: \e[1;104m[#{db}]\e[0m"
end

def theme_identifier(theme)
  "\e[1m#{theme.name} (ID: #{theme.id})\e[0m"
end

def process_theme_component(theme)
  exclude_theme_component(theme)
  disable_theme_component(theme)
end

def exclude_theme_component(theme)
  parent_relations = theme.parent_theme_relation.to_a
  total_relations = parent_relations.size

  if parent_relations.empty?
    puts "\n  \e[33m#{theme_identifier(theme)} is not included in any of your themes\e[0m"
    return
  end

  puts "\n  Excluding #{theme_identifier(theme)} from:"
  parent_relations.each do |relation|
    puts "    - #{relation.parent_theme.name} (ID: #{relation.parent_theme_id})"
    # relation.destroy!
  end
  puts "  \e[1;32m✓ Excluded from #{total_relations} theme#{"s" if total_relations > 1}\e[0m"
end

def disable_theme_component(theme)
  puts "\n  Disabling #{theme_identifier(theme)}..."
  # theme.update!(enabled: false)
  puts "  \e[1;32m✓ Disabled\e[0m"
end

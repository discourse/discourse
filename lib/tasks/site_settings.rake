# frozen_string_literal: true

require "yaml"

desc "Exports site settings"
task "site_settings:export" => :environment do
  h = SiteSettingsTask.export_to_hash
  puts h.to_yaml
end

desc "Imports site settings"
task "site_settings:import" => :environment do
  yml = (STDIN.tty?) ? "" : STDIN.read
  if yml == ""
    puts
    puts "Please specify a settings yml file"
    puts "Example: rake site_settings:import < settings.yml"
    exit 1
  end

  puts
  puts "starting import..."
  puts

  log, counts = SiteSettingsTask.import(yml)

  puts log

  puts
  puts "Results:"
  puts " Updated:   #{counts[:updated]}"
  puts " Not Found: #{counts[:not_found]}"
  puts " Errors:    #{counts[:errors]}"

  exit 1 if counts[:not_found] + counts[:errors] > 0
end

# Outputs a list of Site Settings that may no longer be in use
desc "Find dead site settings"
task "site_settings:find_dead" => :environment do
  setting_names = SiteSettingsTask.names

  setting_names.each do |n|
    if !SiteSetting.respond_to?(n)
      # Likely won't hit here, but just in case
      puts "Setting #{n} does not exist."
    end
  end

  directories = SiteSettingsTask.directories
  dead_settings = []

  if !SiteSettingsTask.rg_installed?
    puts "Please install ripgrep to use this command"
    exit 1
  end

  if !ENV["ALL_THE_PARENT_DIR"]
    puts "To specify a custom parent directory for all-the-themes & all-the-plugins"
    puts "use the ALL_THE_PARENT_DIR ENV var."
  end
  puts "Checking #{setting_names.count} settings in these directories:"
  puts directories
  puts

  setting_names.each do |setting_name|
    count = SiteSettingsTask.rg_search_count("SiteSetting.#{setting_name}", directories.first)
    count =
      SiteSettingsTask.rg_search_count(
        "siteSettings.#{setting_name}",
        directories.first,
      ) if count.zero?
    directories.each do |directory|
      count = SiteSettingsTask.rg_search_count(setting_name, directory) if count.zero?
    end
    if count.zero?
      print setting_name
      dead_settings << setting_name
    else
      print "."
    end
  end

  puts

  if dead_settings.count > 0
    puts "These settings may be unused:"
    puts dead_settings
  else
    puts "No dead settings found."
  end
end

desc "Add missing keyword translation keys"
task "site_settings:add_keyword_translation_keys" => :environment do
  # Manually load the YAML file, since we need to manually dump it at the end
  filename = "#{Rails.root}/config/locales/server.en.yml"

  text = File.read(filename)
  yml = YAML.load_file(filename, aliases: true)

  new_keywords = {}

  added = 0

  yml["en"]["site_settings"].each do |key, value|
    next if !value.is_a?(String)

    if yml["en"]["site_settings"]["keywords"].key?(key)
      new_keywords[key] = yml["en"]["site_settings"]["keywords"][key]
    else
      new_keywords[key] = ""
      added += 1
    end
  end

  removed = yml["en"]["site_settings"]["keywords"].length - new_keywords.length - added

  new_text = ""
  new_keywords.keys.sort.each { |key| new_text += "      #{key}: \"#{new_keywords[key]}\"\n" }

  text.gsub!(/(# BEGIN KEYWORDS\n)(.*)(      # END KEYWORDS)/m, "\\1#{new_text}\\3")

  File.write(filename, text)

  puts "Keyword entries added: #{added}"
  puts "Keyword entries removed: #{removed}"
end

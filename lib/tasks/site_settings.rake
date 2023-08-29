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

  puts "Checking #{setting_names.count} settings in these directories:"
  puts directories
  puts

  setting_names.each do |setting_name|
    count = 0
    count = SiteSettingsTask.rg_search_count("SiteSetting.#{setting_name}", directories[0])
    count =
      SiteSettingsTask.rg_search_count("siteSettings.#{setting_name}", directories[0]) if count == 0
    directories.each do |directory|
      count = SiteSettingsTask.rg_search_count(setting_name, directory) if count == 0
    end
    if count == 0
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

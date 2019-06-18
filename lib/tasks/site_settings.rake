# frozen_string_literal: true

require 'yaml'

desc "Exports site settings"
task "site_settings:export" => :environment do
  h = SiteSettingsTask.export_to_hash
  puts h.to_yaml
end

desc "Imports site settings"
task "site_settings:import" => :environment do
  yml = (STDIN.tty?) ? '' : STDIN.read
  if yml == ''
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

  if counts[:not_found] + counts[:errors] > 0
    exit 1
  end
end

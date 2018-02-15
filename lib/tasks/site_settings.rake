require 'yaml'

class SiteSettingsTask
  def self.export_to_hash
    site_settings = SiteSetting.all_settings
    h = {}
    site_settings.each do |site_setting|
      h.store(site_setting[:setting].to_s, site_setting[:value])
    end
    h
  end
end

desc "Exports site settings"
task "site_settings:export" => :environment do
  h = SiteSettingsTask.export_to_hash
  puts h.to_yaml
end

desc "Imports site settings"
task "site_settings:import" => :environment do
  yml = (STDIN.tty?) ? '' : STDIN.read
  if yml == ''
    puts ""
    puts "Please specify a settings yml file"
    puts "Example: rake site_settings:import < settings.yml"
    exit 1
  end

  puts ""
  puts "starting import..."
  puts ""

  h = SiteSettingsTask.export_to_hash
  counts = { updated: 0, not_found: 0, errors: 0 }

  site_settings = YAML::load(yml)
  site_settings.each do |site_setting|
    key = site_setting[0]
    val = site_setting[1]
    if h.has_key?(key)
      if val != h[key] #only update if different
        begin
          result = SiteSetting.set_and_log(key, val)
          puts "Changed #{key} FROM: #{result.previous_value} TO: #{result.new_value}"
          counts[:updated] += 1
        rescue => e
          puts "ERROR: #{e.message}"
          counts[:errors] += 1
        end
      end
    else
      puts "NOT FOUND: existing site setting not found for #{key}"
      counts[:not_found] += 1
    end
  end
  puts ""
  puts "Results:"
  puts " Updated:   #{counts[:updated]}"
  puts " Not Found: #{counts[:not_found]}"
  puts " Errors:    #{counts[:errors]}"
end

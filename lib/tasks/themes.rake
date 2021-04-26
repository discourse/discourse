# frozen_string_literal: true

require 'yaml'

#
# 2 different formats are accepted:
#
# == JSON format
#
# bin/rake themes:install -- '--{"discourse-something": "https://github.com/discourse/discourse-something"}'
# OR
# bin/rake themes:install -- '--{"discourse-something": {"url": "https://github.com/discourse/discourse-something", default: true}}'
#
# == YAML file formats
#
# theme_name: https://github.com/example/theme.git
# OR
# theme_name:
#   url: https://github.com/example/theme_name.git
#   branch: "master"
#   private_key: ""
#   default: false
#   add_to_all_themes: false  # only for components - install on every theme
#
# In the first form, only the url is required.
#
desc "Install themes & theme components"
task "themes:install" => :environment do |task, args|
  theme_args = (STDIN.tty?) ? '' : STDIN.read
  use_json = theme_args == ''

  theme_args = begin
                 use_json ? JSON.parse(ARGV.last.gsub('--', '')) : YAML::load(theme_args)
               rescue
                 puts use_json ? "Invalid JSON input. \n#{ARGV.last}" : "Invalid YML: \n#{theme_args}"
                 exit 1
               end

  log, counts = ThemesInstallTask.install(theme_args)

  puts log

  puts
  puts "Results:"
  puts " Installed: #{counts[:installed]}"
  puts " Updated:   #{counts[:updated]}"
  puts " Errors:    #{counts[:errors]}"

  if counts[:errors] > 0
    exit 1
  end
end

desc "Update themes & theme components"
task "themes:update" => :environment do |task, args|
  Theme.where(auto_update: true, enabled: true).find_each do |theme|
    begin
      if theme.remote_theme.present?
        puts "Updating #{theme.name}..."
        theme.remote_theme.update_from_remote
        theme.save!
        unless theme.remote_theme.last_error_text.nil?
          puts "Error updating #{theme.name}: #{theme.remote_theme.last_error_text}"
          exit 1
        end
      end
    rescue => e
      STDERR.puts "Failed to update #{theme.name}"
      STDERR.puts e
      STDERR.puts e.backtrace
      exit 1
    end
  end
end

desc "List all the installed themes on the site"
task "themes:audit" => :environment do
  components = Set.new
  puts "Selectable themes"
  puts "-----------------"

  Theme.where("(enabled OR user_selectable) AND NOT component").each do |theme|
    puts theme.remote_theme&.remote_url || theme.name
    theme.child_themes.each do |child|
      if child.enabled
        repo = child.remote_theme&.remote_url || child.name
        components << repo
      end
    end
  end

  puts
  puts "Selectable components"
  puts "---------------------"
  components.each do |repo|
    puts repo
  end
end

desc "Run QUnit tests of a theme/component"
task "themes:qunit", :theme_name_or_url do |t, args|
  name_or_url = args[:theme_name_or_url]
  if name_or_url.blank?
    raise "A theme name or URL must be provided."
  end
  if name_or_url =~ /^(url|name)=(.+)/
    cmd = "THEME_#{Regexp.last_match(1).upcase}=#{Regexp.last_match(2)} "
    cmd += `which rake`.strip + " qunit:test"
    sh cmd
  else
    raise <<~MSG
      Cannot parse passed argument #{name_or_url.inspect}.
      Usage:
        `bundle exec rake themes:unit[url=<theme_url>]`
        OR
        `bundle exec rake themes:unit[name=<theme_name>]`
    MSG
  end
end

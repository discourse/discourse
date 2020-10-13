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

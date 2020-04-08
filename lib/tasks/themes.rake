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
#   install_to_all_themes: false  # only for components - install on every theme
#
# In the first form, only the url is required.
#
desc "Install themes & theme components"
task "themes:install" => :environment do |task, args|

  theme_args = (STDIN.tty?) ? '' : STDIN.read
  use_json = theme_args == ''

  if use_json
    begin
      theme_args = JSON.parse(ARGV.last.gsub('--', ''))
    rescue
      puts "Invalid JSON input. \n#{ARGV.last}"
      exit 1
    end
  else
    begin
      theme_args = YAML::load(theme_args)
    rescue
      puts "Invalid YML: \n#{theme_args}"
      exit 1
    end
  end


  log, counts = ThemesInstallTask.install(theme_args)

  puts log

  puts
  puts "Results:"
  puts " Installed: #{counts[:installed]}"
  puts " Updated:   #{counts[:updated]}"
  puts " Skipped:   #{counts[:skipped]}"
  puts " Errors:    #{counts[:errors]}"

  if counts[:errors] > 0
    exit 1
  end
end

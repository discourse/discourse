# frozen_string_literal: true

require 'yaml'

# == YAML file format
#
# 2 different formats are accepted:
#
# theme_name: https://github.com/example/theme.git
#
# theme_name:
#   url: https://github.com/example/theme.git
#   branch: abc
#   private_key: ...
#   default: true
#
# In the second form, only the url is required.
#
desc "Install themes & theme components"
task "themes:install" => :environment do
  yml = (STDIN.tty?) ? '' : STDIN.read
  if yml == ''
    puts
    puts "Please specify a themes yml file"
    puts "Example: rake themes:install < themes.yml"
    exit 1
  end

  log, counts = ThemesInstallTask.install(yml)

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

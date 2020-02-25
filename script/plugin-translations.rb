# frozen_string_literal: true

if ARGV.empty?
  puts 'Usage: ', ''
  puts '  ruby plugin-translations.rb <plugins_base_dir>'
  puts '  ruby plugin-translations.rb <plugins_base_dir> push  (to git push)'
  exit 1
end

require 'bundler'

class PluginTxUpdater

  attr_reader :failed

  PLUGINS = [
    'discourse-adplugin',
    'discourse-akismet',
    'discourse-assign',
    'discourse-cakeday',
    'discourse-canned-replies',
    'discourse-characters-required',
    'discourse-chat-integration',
    'discourse-checklist',
    'discourse-data-explorer',
    'discourse-math',
    'discourse-oauth2-basic',
    'discourse-patreon',
    'discourse-saved-searches',
    'discourse-solved',
    'discourse-user-notes',
    'discourse-voting'
  ]

  def initialize(base_dir, push)
    @push = !!push
    @base_dir = base_dir
    @failed = []
  end

  def perform
    PLUGINS.each do |plugin_name|
      plugin_dir = File.join(@base_dir, plugin_name)
      Bundler.with_clean_env do
        Dir.chdir(plugin_dir) do # rubocop:disable DiscourseCops/NoChdir because this is not part of the app
          puts '', plugin_dir, '-' * 80, ''

          begin
            system_cmd('git pull')
            system_cmd('bundle update translations-manager')
            system_cmd('bundle exec bin/pull_translations.rb')
            system_cmd('git add config/locales/*')
            system_cmd('git add Gemfile.lock') rescue true # might be gitignored
            system_cmd('git add .tx/config') rescue true
            system_cmd('git commit -m "Update translations"')
            system_cmd('git push origin master') if @push
          rescue => e
            puts "Failed for #{plugin_name}. Skipping...", ''
            @failed << plugin_name
          end
        end
      end
    end
  end

  def system_cmd(s)
    rc = system(s)
    raise RuntimeError.new($?) if rc != true
  end
end

base_dir = File.expand_path(ARGV[0])

unless File.exists?(base_dir)
  puts '', "Dir '#{base_dir}' doesn't exist."
  exit 1
end

updates = PluginTxUpdater.new(base_dir, ARGV[1]&.downcase == 'push')
updates.perform

if updates.failed.empty?
  puts '', "All plugins updated successfully!", ''
else
  if updates.failed.size < PluginTxUpdater::PLUGINS.size
    puts '', "These plugins updated successfully: ", ''
    puts PluginTxUpdater::PLUGINS - updates.failed
  end
  puts '', "Errors were encountered while updating these plugins:", ''
  puts updates.failed
end

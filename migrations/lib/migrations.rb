# frozen_string_literal: true

require "bundler/inline"
require "bundler/ui"

module Migrations
  def self.root_path
    @root_path ||= File.expand_path("..", __dir__)
  end

  def self.load_gemfile(relative_path)
    path = File.join(Migrations.root_path, "config/gemfiles")
    path = File.expand_path(relative_path, path)

    unless File.exist?(path)
      warn "Could not find Gemfile at #{path}"
      exit 1
    end

    # Create new UI and set level to confirm to avoid printing unnecessary messages
    bundler_ui = Bundler::UI::Shell.new
    bundler_ui.level = "confirm"

    begin
      gemfile(true, ui: bundler_ui) do
        # rubocop:disable Security/Eval
        eval(File.read(path), nil, path, 1)
        # rubocop:enable Security/Eval
      end
    rescue Bundler::BundlerError => e
      warn "\e[31m#{e.message}\e[0m"
      exit 1
    end
  end

  def self.load_rails_environment
    rails_root = File.expand_path("../..", __dir__)
    # rubocop:disable Discourse/NoChdir
    Dir.chdir(rails_root) { require File.join(rails_root, "config/environment") }
    # rubocop:enable Discourse/NoChdir
  end

  def self.configure_zeitwerk(*directories)
    require "zeitwerk"

    root_path = Migrations.root_path

    loader = Zeitwerk::Loader.new
    directories.each do |dir|
      loader.push_dir(File.expand_path(dir, root_path), namespace: Migrations)
    end
    loader.setup
  end
end

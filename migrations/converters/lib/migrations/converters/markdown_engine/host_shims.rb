# frozen_string_literal: true

require "logger"
require "open3"
require "pathname"

module Migrations
  module Converters
    module MarkdownEngine
      # `AssetProcessor` (the host application's transpiler) reaches for a few
      # host constants: `Rails.root`/`Rails.logger`, `GlobalSetting`, and — only
      # when its own compiled processor is missing — `Discourse::Utils` to shell
      # out to pnpm. In a converter process none of these exist, and booting the
      # application to get them is exactly what this component avoids, so the
      # minimal stand-ins are installed instead. Inside a booted application
      # (the parity specs) every constant is already defined and nothing here
      # runs.
      module HostShims
        def self.install!(discourse_root)
          install_rails(discourse_root) unless defined?(::Rails)
          install_global_setting unless defined?(::GlobalSetting)
          install_discourse unless defined?(::Discourse)
        end

        def self.install_rails(discourse_root)
          root = Pathname.new(discourse_root)
          logger = Logger.new(IO::NULL)
          rails = Module.new
          rails.define_singleton_method(:root) { root }
          rails.define_singleton_method(:logger) { logger }
          Object.const_set(:Rails, rails)
        end
        private_class_method :install_rails

        def self.install_global_setting
          global_setting = Module.new
          global_setting.define_singleton_method(:mini_racer_single_threaded) { false }
          Object.const_set(:GlobalSetting, global_setting)
        end
        private_class_method :install_global_setting

        def self.install_discourse
          utils = Module.new
          utils.define_singleton_method(:execute_command) do |*command|
            stdout, stderr, status = Open3.capture3(*command)
            raise "Command failed: #{command.join(" ")}\n#{stderr}" unless status.success?
            stdout
          end
          discourse = Module.new
          discourse.const_set(:Utils, utils)
          Object.const_set(:Discourse, discourse)
        end
        private_class_method :install_discourse
      end
    end
  end
end

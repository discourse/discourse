# frozen_string_literal: true

require "fileutils"
require "logger"
require "open3"
require "pathname"

module Migrations
  module Converters
    module MarkdownEngine
      # The host application's build classes (`PrecompiledBundle` for the
      # pretty-text bundle, `AssetProcessor` for plugin-feature transpiles)
      # reach for `Rails.root`/`Rails.logger`, `GlobalSetting`, and
      # `Discourse::Utils`. A converter's build subprocess has none of them, and
      # booting the application to get them is what this component avoids, so
      # minimal stand-ins go in instead. Inside a booted application every
      # constant is already defined and nothing here runs.
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
          utils.define_singleton_method(:execute_command) do |*command, chdir: nil|
            options = chdir ? { chdir: } : {}
            stdout, stderr, status = Open3.capture3(*command, **options)
            raise "Command failed: #{command.join(" ")}\n#{stderr}" unless status.success?
            stdout
          end
          utils.define_singleton_method(:atomic_write_file) do |destination, contents|
            existing =
              begin
                File.read(destination)
              rescue Errno::ENOENT
                nil
              end
            unless existing == contents
              FileUtils.mkdir_p(File.dirname(destination))
              temp_destination = "#{destination}.#{Process.pid}.tmp"
              File.write(temp_destination, contents)
              File.rename(temp_destination, destination)
            end
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

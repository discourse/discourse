# frozen_string_literal: true

require_relative "../migrations"
require_relative "./settings"
require_relative "./fixer"
require_relative "./uploader"
require_relative "./optimizer"

module Migrations
  load_rails_environment

  load_gemfiles("common")
  configure_zeitwerk("lib/common")

  module Uploads
    class CLI < Thor
      default_task :execute

      class_option :settings,
                   type: :string,
                   aliases: "-s",
                   default: "./migrations/config/process_uploads.yml",
                   banner: "SETTINGS_FILE",
                   desc: "Upload settings file"

      def initialize(*args)
        super

        EXIFR.logger = Logger.new(nil)
        @settings = Settings.from_file(options[:settings])
      end

      def self.exit_on_failure?
        true
      end

      desc "execute [--settings=SETTINGS_FILE]", "Process uploads"
      def execute
        return run_fixer! if @settings[:fix_missing]

        Uploader.run!(@settings)

        run_optimizer! if @settings[:create_optimized_images]
      end

      desc "fix-missing [--settings=SETTINGS_FILE]", "Fix missing uploads"
      def fix_missing
        run_fixer!
      end

      desc "optimize [--settings=SETTINGS_FILE]", "Optimize uploads"
      def optimize
        run_optimize!
      end

      private

      def run_fixer!
        Fixer.run!(@settings)
      end

      def run_optimizer!
        Optimizer.run!(@settings)
      end
    end
  end
end

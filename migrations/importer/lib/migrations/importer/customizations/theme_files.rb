# frozen_string_literal: true

require "digest"
require "json"

module Migrations
  module Importer
    module Customizations
      # Files of a local theme as written into a bundle, and a fingerprint to
      # tell whether a theme on the target already matches them.
      module ThemeFiles
        ABOUT_JSON = "about.json"
        UNSTABLE_ABOUT_KEYS = %w[learn_more].freeze

        def self.export(theme)
          ::ThemeStore::ZipExporter
            .new(theme)
            .with_export_dir do |dir|
              normalize_about_json(dir, theme)
              yield dir
            end
        end

        # about.json lists the theme's selected palette even when the theme
        # doesn't own it; importing that would create a copy owned by the theme.
        # Palettes travel on their own and are assigned by name instead.
        def self.normalize_about_json(dir, theme)
          path = File.join(dir, ABOUT_JSON)
          return unless File.exist?(path)

          about = JSON.parse(File.read(path))
          owned = theme.color_schemes.map(&:name)
          about["color_schemes"] = (about["color_schemes"] || {}).slice(*owned)
          File.write(path, JSON.pretty_generate(about))
        end

        def self.fingerprint(dir)
          Dir
            .glob("**/*", base: dir)
            .sort
            .filter_map do |relative|
              path = File.join(dir, relative)
              next unless File.file?(path)

              if relative == ABOUT_JSON
                about = JSON.parse(File.read(path)).except(*UNSTABLE_ABOUT_KEYS)
                [relative, Digest::SHA1.hexdigest(JSON.generate(deep_sort(about)))]
              else
                [relative, Digest::SHA1.file(path).hexdigest]
              end
            end
        end

        def self.same?(theme, dir)
          export(theme) { |current| fingerprint(current) == fingerprint(dir) }
        end

        def self.deep_sort(value)
          case value
          when Hash
            value.sort.to_h { |k, v| [k, deep_sort(v)] }
          when Array
            value.map { |v| deep_sort(v) }
          else
            value
          end
        end
        private_class_method :deep_sort
      end
    end
  end
end

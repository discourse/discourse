# frozen_string_literal: true

require "yaml"

module Migrations
  module Converters
    module MarkdownEngine
      # The source-site inputs a `Context` is built from. Site settings start
      # from the checkout's own YAML defaults and are overridden by whatever the
      # source database provides for the keys the markdown pipeline reads; a
      # spec keeps `SETTING_KEYS` in sync with the JavaScript by grepping the
      # same files the `Bundle` loads. The keys cover core and exactly the
      # plugins in `Bundle::CORE_MARKDOWN_PLUGINS`.
      class Config
        # Every `siteSettings.*` key the loaded markdown JavaScript reads.
        SETTING_KEYS = %w[
          allowed_href_schemes
          allowed_iframes
          chat_enabled
          checklist_enabled
          default_code_lang
          discourse_events_enabled
          discourse_graphviz_enabled
          discourse_local_dates_email_format
          discourse_local_dates_email_timezone
          discourse_local_dates_enabled
          discourse_math_enable_asciimath
          discourse_math_enable_latex_delimiters
          discourse_math_enabled
          discourse_math_provider
          discourse_post_event_enabled
          emoji_set
          enable_emoji
          enable_emoji_shortcuts
          enable_inline_emoji_translation
          enable_markdown_footnotes
          enable_markdown_linkify
          enable_markdown_typographer
          enable_mentions
          external_emoji_url
          markdown_linkify_tlds
          markdown_typographer_quotation_marks
          policy_enabled
          poll_enabled
          poll_maximum_options
          secure_uploads
          spoiler_enabled
          traditional_markdown_linebreaks
          unicode_usernames
        ].freeze

        # Read from the options directly, not through `siteSettings`.
        AVATAR_SIZES_KEY = "avatar_sizes"

        attr_reader :settings, :category_slugs, :tag_names, :additional_options

        # @param source_settings [Hash] the source site's settings; only
        #   `SETTING_KEYS` are used. String values for boolean/integer settings
        #   are coerced against the default's type.
        # @param category_slugs [Array<String>] the source's category slug
        #   paths, a nested category as `parent:child`
        def initialize(
          source_settings: {},
          category_slugs: [],
          tag_names: [],
          custom_emoji_names: [],
          additional_options: {}
        )
          defaults = self.class.default_settings
          overrides =
            source_settings
              .transform_keys(&:to_s)
              .slice(*SETTING_KEYS)
              .to_h { |key, value| [key, self.class.coerce(value, defaults[key])] }
          @settings = defaults.merge(overrides)
          # Injected already {NameNormalizer}-folded; runtime.js folds the
          # sought slug the same way.
          @category_slugs = category_slugs.map { |slug| NameNormalizer.normalize(slug) }
          @tag_names = tag_names.map { |name| NameNormalizer.normalize(name) }
          @custom_emoji_names = custom_emoji_names.map(&:to_s)
          @additional_options = additional_options
        end

        # The lookup set runtime.js answers `#slug` against: a category is
        # addressed by its own slug, so a nested category enters as its leaf.
        # The extractor still validates the parent path against
        # {#hashtag_names}.
        def category_lookup_slugs
          @category_lookup_slugs ||=
            @category_slugs.map { |path| path.split(":").last }.compact.uniq
        end

        # Every hashtag name the source has, in the form a post spells it (a
        # nested category as the full path) — what a `RawExtractor` resolves
        # against.
        def hashtag_names
          @hashtag_names ||= CompactStringSet.new(@category_slugs + @tag_names)
        end

        def avatar_sizes
          self.class.yaml_defaults[AVATAR_SIZES_KEY].to_s.split("|").map(&:to_i)
        end

        def custom_emoji
          # Only the names matter for scanning; the URL just has to be a
          # plausible path for token construction.
          @custom_emoji_names.to_h { |name| [name, "/images/emoji/custom/#{name}.png"] }
        end

        def self.default_settings
          yaml_defaults.slice(*SETTING_KEYS)
        end

        def self.yaml_defaults
          @yaml_defaults ||=
            begin
              root = MarkdownEngine.discourse_root
              files =
                [File.join(root, "config", "site_settings.yml")] +
                  Bundle::CORE_MARKDOWN_PLUGINS.filter_map do |plugin|
                    path = File.join(root, "plugins", plugin, "config", "settings.yml")
                    path if File.exist?(path)
                  end

              defaults = {}
              files.each do |file|
                YAML
                  .safe_load(File.read(file), aliases: true)
                  .each_value do |group|
                    next unless group.is_a?(Hash)
                    group.each do |name, value|
                      next unless SETTING_KEYS.include?(name) || name == AVATAR_SIZES_KEY
                      defaults[name] = value.is_a?(Hash) ? value["default"] : value
                    end
                  end
              end
              defaults
            end
        end

        def self.coerce(value, default)
          return value unless value.is_a?(String)

          case default
          when true, false
            %w[t true].include?(value.downcase)
          when Integer
            value.to_i
          else
            value
          end
        end
      end
    end
  end
end

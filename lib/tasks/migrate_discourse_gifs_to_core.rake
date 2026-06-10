# frozen_string_literal: true

require "discourse_gifs"

module DiscourseGifsMigration
  # Mapping from each TC provider's theme settings to core site settings.
  # `value:` is an optional lookup table for non-1:1 translations.
  PROVIDER_MAPPINGS = {
    "giphy" => {
      "giphy_file_format" => {
        name: "klipy_file_detail",
      },
      "giphy_content_rating" => {
        name: "klipy_content_filter",
        value: {
          "g" => "high",
          "pg" => "medium",
          "pg-13" => "low",
          "r" => "low",
        },
      },
      "giphy_locale" => {
        name: "klipy_locale",
      },
    },
    "tenor" => {
      "tenor_file_detail" => {
        name: "klipy_file_detail",
        value: {
          "mediumgif" => "webp",
          "tinygif" => "webp",
          "nanogif" => "webp",
          "gif" => "gif",
        },
      },
      "tenor_content_filter" => {
        name: "klipy_content_filter",
      },
      "tenor_country" => {
        name: "klipy_country",
      },
      "tenor_locale" => {
        name: "klipy_locale",
      },
    },
    "klipy" => {
      "klipy_api_key" => {
        name: "klipy_api_key",
      },
      "klipy_file_detail" => {
        name: "klipy_file_detail",
      },
      "klipy_content_filter" => {
        name: "klipy_content_filter",
      },
      "klipy_country" => {
        name: "klipy_country",
      },
      "klipy_locale" => {
        name: "klipy_locale",
      },
    },
  }.freeze

  # Settings the TC applied regardless of provider — migrated for everyone.
  SHARED_MAPPINGS = {
    "limit_infinite_search_results" => {
      name: "klipy_limit_infinite_search_results",
    },
    "max_results_limit" => {
      name: "klipy_max_results_limit",
    },
  }.freeze

  module_function

  def find_components
    if ENV["RAILS_DB"].present?
      db = ENV["RAILS_DB"]

      if !RailsMultisite::ConnectionManagement.has_db?(db)
        default_db = RailsMultisite::ConnectionManagement::DEFAULT
        puts "\e[31m✗ Database \e[1;101m[#{db}]\e[0m \e[31mnot found\e[0m"
        puts "Using default database instead: \e[1;104m[#{default_db}]\e[0m\n\n"
        db = default_db
      end

      RailsMultisite::ConnectionManagement.establish_connection(db: db)
      Array(find_component_in_db(db))
    else
      [].tap do |components|
        RailsMultisite::ConnectionManagement.each_connection do |db|
          components.concat(Array(find_component_in_db(db)))
        end
      end
    end
  end

  def find_component_in_db(db)
    puts "Accessing database: \e[1;104m[#{db}]\e[0m"
    puts "  Searching for #{DiscourseGifs::COMPONENT_NAME} theme component..."

    themes =
      RemoteTheme
        .where(remote_url: DiscourseGifs::REMOTE_URLS)
        .includes(theme: :theme_settings)
        .map(&:theme)

    if themes.length > 1
      puts "  \e[33mMultiple (#{themes.length}) #{DiscourseGifs::COMPONENT_NAME} components found:\e[0m"
      themes.each { |t| puts "    - #{t.name} (ID: #{t.id})" }
      puts "  \e[33mInstall a single instance before running this task.\e[0m"
      return nil
    elsif themes.one?
      theme = themes.first
      puts "  \e[1;34m✓ Found: \e[1m#{theme.name} (ID: #{theme.id})\e[0m"
      return theme
    end

    puts "  \e[33m✗ Not found.\e[0m"
    nil
  end

  def migrate_component(theme, enable_gifs:)
    puts "\n  Migrating settings for \e[1m#{theme.name} (ID: #{theme.id})\e[0m..."

    overrides = theme.theme_settings.each_with_object({}) { |ts, h| h[ts.name] = ts.value }
    # TC's default api_provider is "giphy" — applies to any site that never picked one.
    provider = overrides["api_provider"].presence || "giphy"
    puts "  Detected provider: \e[1m#{provider}\e[0m"

    mapping = (PROVIDER_MAPPINGS[provider] || {}).merge(SHARED_MAPPINGS)

    migrated = 0
    errors = []

    mapping.each do |tc_name, target|
      raw = overrides[tc_name]
      next if raw.blank?

      new_value = target[:value] ? (target[:value][raw] || raw) : raw

      begin
        SiteSetting.set_and_log(
          target[:name],
          new_value,
          Discourse.system_user,
          "Migrated from #{DiscourseGifs::COMPONENT_NAME} theme component",
        )
        puts "    - \e[0;31m#{tc_name}: #{raw}\e[0m => \e[0;32m#{target[:name]}: #{new_value}\e[0m"
        migrated += 1
      rescue StandardError => e
        errors << e
        puts "    \e[31m- failed to migrate '#{tc_name}': \e[1m#{e.message}\e[0m"
      end
    end

    if enable_gifs
      begin
        SiteSetting.set_and_log(
          :enable_gifs,
          true,
          Discourse.system_user,
          "Migrated from #{DiscourseGifs::COMPONENT_NAME} theme component",
        )
        puts "    - \e[0;32menable_gifs: true\e[0m (auto-enabled per task argument)"
        migrated += 1
      rescue StandardError => e
        errors << e
        puts "    \e[31m- failed to enable enable_gifs: \e[1m#{e.message}\e[0m"
      end
    end

    puts "  \e[1;32m✓ Migrated #{migrated} setting#{"s" if migrated != 1}\e[0m"
    puts "  \e[1;31m#{errors.size} error#{"s" if errors.size != 1}\e[0m" if errors.any?
  end
end

desc "Migrate #{DiscourseGifs::COMPONENT_NAME} theme component settings to core site settings. " \
       "Set ENABLE_GIFS=1 to also flip enable_gifs to true after migration."
task "themes:discourse_gifs:migrate" => :environment do
  enable_gifs = %w[true yes 1].include?(ENV["ENABLE_GIFS"].to_s.strip.downcase)

  components = DiscourseGifsMigration.find_components

  if components.any?
    puts "\nMigrating settings..."
    puts "---------------------"
    components.each { |c| DiscourseGifsMigration.migrate_component(c, enable_gifs: enable_gifs) }
  else
    puts "\nNo #{DiscourseGifs::COMPONENT_NAME} theme component found. Nothing to migrate."
  end
end

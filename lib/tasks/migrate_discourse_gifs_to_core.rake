# frozen_string_literal: true

module DiscourseGifsMigration
  COMPONENT_NAME = "discourse-gifs"

  REPO_URLS = %w[
    https://github.com/discourse/discourse-gifs
    https://github.com/xfalcox/discourse-gifs
  ].freeze

  REMOTE_URLS = REPO_URLS.flat_map { |url| [url, "#{url}.git"] }.freeze

  # Klipy expects locale in xx_YY form (ISO 639-1 language + ISO 3166-1 alpha-2
  # country). Giphy stores a bare language code, so each of its locale choices is
  # translated to a representative xx_YY. Where a language spans several countries
  # the predominant one is used — these picks are deliberate, not 1:1:
  #   en→en_US, pt→pt_BR, es→es_ES, ar→ar_SA, bn→bn_BD, ms→ms_MY.
  # "iw" is Giphy's legacy code for Hebrew, normalised to the modern "he".
  GIPHY_LOCALES = {
    "ar" => "ar_SA",
    "bn" => "bn_BD",
    "cs" => "cs_CZ",
    "da" => "da_DK",
    "de" => "de_DE",
    "en" => "en_US",
    "es" => "es_ES",
    "fa" => "fa_IR",
    "fi" => "fi_FI",
    "fr" => "fr_FR",
    "hi" => "hi_IN",
    "hu" => "hu_HU",
    "id" => "id_ID",
    "it" => "it_IT",
    "iw" => "he_IL",
    "ja" => "ja_JP",
    "ko" => "ko_KR",
    "ms" => "ms_MY",
    "nl" => "nl_NL",
    "no" => "no_NO",
    "pl" => "pl_PL",
    "pt" => "pt_BR",
    "ro" => "ro_RO",
    "ru" => "ru_RU",
    "sv" => "sv_SE",
    "th" => "th_TH",
    "tl" => "tl_PH",
    "tr" => "tr_TR",
    "uk" => "uk_UA",
    "vi" => "vi_VN",
    "zh-CN" => "zh_CN",
    "zh-TW" => "zh_TW",
  }.freeze

  # Mapping from each TC provider's theme settings to core site settings.
  # `value:` is an optional lookup table for non-1:1 translations.
  #
  # Tenor and Klipy already store locale in Klipy's xx_YY form, so their locale
  # carries across unchanged; Giphy's bare language code is translated via
  # GIPHY_LOCALES above.
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
        value: GIPHY_LOCALES,
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

  GIF_PROVIDER_DOMAINS = %w[giphy.com tenor.com].freeze

  KLIPY_MEDIA_HOSTS = %w[static.klipy.com static1.klipy.com static2.klipy.com].freeze

  # SGR foreground color codes for terminal output
  COLORS = { red: 31, green: 32, yellow: 33, blue: 34 }.freeze

  module_function

  def paint(text, color = nil, bold: false)
    codes = []
    codes << 1 if bold
    codes << COLORS.fetch(color) if color
    return text if codes.empty?

    "\e[#{codes.join(";")}m#{text}\e[0m"
  end

  # A highlighted [db] label (blue, or red when the named db is missing).
  def db_label(db, missing: false)
    "\e[#{missing ? "1;101" : "1;104"}m[#{db}]\e[0m"
  end

  # indented bullet lines used throughout the migration output
  def item(text)
    puts "    - #{text}"
  end

  def success(text)
    item(paint(text, :green))
  end

  def failure(text)
    item(paint(text, :red))
  end

  def status(text, color, bold: false)
    puts "  #{paint(text, color, bold: bold)}"
  end

  def migrate_all(enable_gifs:)
    migrated_any = false

    each_target_db do |db|
      theme = find_component_in_db(db)
      next unless theme

      unless migrated_any
        puts "\nMigrating settings..."
        puts "---------------------"
        migrated_any = true
      end

      migrate_component(theme, enable_gifs: enable_gifs)
    end

    puts "\nNo #{COMPONENT_NAME} theme component found. Nothing to migrate." unless migrated_any
  end

  def each_target_db
    if ENV["RAILS_DB"].present?
      db = ENV["RAILS_DB"]

      if !RailsMultisite::ConnectionManagement.has_db?(db)
        default_db = RailsMultisite::ConnectionManagement::DEFAULT
        puts "#{paint("✗ Database", :red)} #{db_label(db, missing: true)} #{paint("not found", :red)}"
        puts "Using default database instead: #{db_label(default_db)}\n\n"
        db = default_db
      end

      RailsMultisite::ConnectionManagement.with_connection(db) { yield db }
    else
      RailsMultisite::ConnectionManagement.each_connection { |db| yield db }
    end
  end

  def find_component_in_db(db)
    puts "Accessing database: #{db_label(db)} (#{RailsMultisite::ConnectionManagement.current_hostname})"
    puts "Searching for #{COMPONENT_NAME} theme component..."

    themes =
      RemoteTheme.where(remote_url: REMOTE_URLS).includes(theme: :theme_settings).map(&:theme)

    if themes.length > 1
      status("Multiple (#{themes.length}) #{COMPONENT_NAME} components found:", :yellow)
      themes.each { |t| item("#{t.name} (ID: #{t.id})") }
      status("Install a single instance before running this task.", :yellow)
      return nil
    elsif themes.one?
      theme = themes.first
      status("✓ Found: #{theme.name} (ID: #{theme.id})", :blue, bold: true)
      return theme
    end

    status("✗ Not found.", :yellow)
    nil
  end

  def migrate_component(theme, enable_gifs:)
    puts "\n  Migrating settings for #{paint("#{theme.name} (ID: #{theme.id})", bold: true)}..."

    values =
      theme.settings.each_with_object({}) { |(name, setting), h| h[name.to_s] = setting.value }
    provider = values["api_provider"].presence || "giphy" # giphy is the default provider in theme component
    puts "  Detected provider: #{paint(provider, bold: true)}"

    mapping = (PROVIDER_MAPPINGS[provider] || {}).merge(SHARED_MAPPINGS)

    migrated = 0
    errors = []

    mapping.each do |tc_name, target|
      raw = values[tc_name]
      next if raw.blank?

      new_value = target[:value] ? (target[:value][raw] || raw) : raw

      begin
        # set_and_log returns nil when the value already matches, so we only
        # report/count settings that actually changed — reading effective
        # values means most settings already equal core's default.
        changed =
          SiteSetting.set_and_log(
            target[:name],
            new_value,
            Discourse.system_user,
            "Migrated from #{COMPONENT_NAME} theme component",
          )
        next unless changed

        success("#{tc_name}: #{raw} => #{target[:name]}: #{new_value}")
        migrated += 1
      rescue StandardError => e
        errors << e
        failure("failed to migrate '#{tc_name}': #{e.message}")
      end
    end

    errors.concat(migrate_disabled_image_download_domains)
    errors.concat(migrate_translation_overrides(theme))

    if enable_gifs
      begin
        SiteSetting.set_and_log(
          :enable_gifs,
          true,
          Discourse.system_user,
          "Migrated from #{COMPONENT_NAME} theme component",
        )
        success("enable_gifs: true (auto-enabled after migration)")
        migrated += 1
      rescue StandardError => e
        errors << e
        failure("failed to enable enable_gifs: #{e.message}")
      end
    end

    status("✓ Migrated #{migrated} setting#{"s" if migrated != 1}", :green, bold: true)
    status("#{errors.size} error#{"s" if errors.size != 1}", :red, bold: true) if errors.any?
  end

  # Sites that blocked the old provider's gifs from being downloaded via
  # `disabled_image_download_domains` should keep blocking gifs after the switch
  # to Klipy. We only act when a known gif-provider host is already listed, so
  # we never touch the setting on sites that weren't blocking gifs
  def migrate_disabled_image_download_domains
    hosts =
      SiteSetting.disabled_image_download_domains.to_s.split("|").map(&:strip).reject(&:empty?)
    return [] unless hosts.any? { |host| gif_provider_host?(host) }

    missing = KLIPY_MEDIA_HOSTS - hosts
    return [] if missing.empty?

    SiteSetting.set_and_log(
      :disabled_image_download_domains,
      (hosts + missing).join("|"),
      Discourse.system_user,
      "Added Klipy media hosts so gifs stay blocked after migrating from " \
        "#{COMPONENT_NAME} theme component",
    )
    success(
      "disabled_image_download_domains += #{missing.join(", ")} " \
        "(preserving existing gif download block)",
    )
    []
  rescue StandardError => e
    failure("failed to update disabled_image_download_domains: #{e.message}")
    [e]
  end

  def gif_provider_host?(host)
    GIF_PROVIDER_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
  end

  def migrate_translation_overrides(theme)
    theme
      .theme_translation_overrides
      .each_with_object([]) do |override, errors|
        core_key = "js.#{override.translation_key.sub(/\Agif\./, "gifs.")}"
        next unless I18n.exists?(core_key, :en)

        begin
          TranslationOverride.upsert!(override.locale, core_key, override.value)
          success("#{override.translation_key} (#{override.locale}) => #{core_key}")
        rescue StandardError => e
          errors << e
          failure("failed to migrate translation '#{override.translation_key}': #{e.message}")
        end
      end
  end
end

desc "Migrate discourse-gifs theme component settings to core site settings. " \
       "enable_gifs is flipped to true after migration by default; set ENABLE_GIFS=0 to skip that."
task "themes:discourse_gifs:migrate" => :environment do
  enable_gifs = !%w[false no 0].include?(ENV["ENABLE_GIFS"].to_s.strip.downcase)

  DiscourseGifsMigration.migrate_all(enable_gifs: enable_gifs)
end

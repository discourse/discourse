# frozen_string_literal: true

require "colored2"
require "psych"
require_relative "../lib/i18n/locale_file_walker"
require_relative "../lib/i18n/duplicate_key_finder"

class I18nLinter
  def initialize(filenames_or_patterns)
    @filenames = filenames_or_patterns.map { |fp| Dir[fp] }.flatten
    @errors = {}
  end

  def run
    has_errors = false

    @filenames.each do |filename|
      [LocaleFileValidator.new(filename), *translation_validators(filename)].each do |validator|
        if validator.has_errors?
          validator.print_errors
          has_errors = true
        end
      end
    end

    exit 1 if has_errors
  end

  private

  def translation_validators(english_path)
    return [] if !english_path.end_with?(".en.yml")

    english = Psych.safe_load(File.read(english_path), aliases: true)
    return [] if !english.is_a?(Hash) || !english["en"].is_a?(Hash)

    Dir[english_path.sub(/\.en\.yml\z/, ".*.yml")]
      .reject { |path| path == english_path }
      .map { |path| LocaleFileValidator.new(path, english: english["en"]) }
  rescue Psych::Exception
    []
  end
end

class LocaleFileValidator
  # Format: "banned phrase" => "recommendation"
  BANNED_PHRASES = { "color scheme" => "color palette", "private message" => "personal message" }

  ERROR_MESSAGES = {
    invalid_relative_links:
      "The following keys have relative links, but do not start with %{base_url} or %{base_path}:",
    invalid_relative_image_sources:
      "The following keys have relative image sources, but do not start with %{base_url} or %{base_path}:",
    invalid_interpolation_key_format:
      "The following keys use {{key}} instead of %{key} for interpolation keys:",
    wrong_pluralization_keys:
      "Pluralized strings must have only the sub-keys 'one' and 'other'.\nThe following keys have missing or additional keys:",
    invalid_file_format:
      "The file is not a valid YAML format or does not contain a valid locale structure.",
    duplicate_keys: "The following keys are defined more than once:",
    invalid_top_level_key: "The locale from the file name must be the only top-level key.",
    invalid_interpolation_keys:
      "The following keys contain interpolation keys made only of digits or symbols:",
    incompatible_with_english: "The following keys have a different type than in the English file:",
    missing_client_sections: "The following required top-level sections are missing:",
    invalid_one_keys:
      "The following keys contain the number 1 instead of the interpolation key %{count}:",
    invalid_setting_link_format:
      "The following keys contain malformed setting link markers.\nUse {{setting:setting_name}} or {{settings:name_one,name_two|Link label}} (lowercase snake_case names, no spaces around commas):",
  }.merge(
    BANNED_PHRASES
      .map do |banned, recommendation|
        [
          "banned_phrase_#{banned}",
          "The following keys contain the banned phrase '#{banned}' (use '#{recommendation}' instead)",
        ]
      end
      .to_h,
  )

  # Must stay in sync with SETTING_LINK_PATTERN and SETTINGS_LINK_PATTERN in
  # lib/site_settings/label_formatter.rb — markers that don't match there are
  # rendered verbatim, so lint anything that only looks like one.
  VALID_SETTING_LINK_REGEX =
    /\{\{setting:[a-z][a-z0-9_]*\}\}|\{\{settings:[a-z][a-z0-9_]*(?:,[a-z][a-z0-9_]*)*(?:\|[^{}|]+)?\}\}/

  SETTING_LINK_START_REGEX = /{{settings?:/
  VALID_SETTING_LINK_AT_START_REGEX = /\A(?:#{VALID_SETTING_LINK_REGEX})/

  PLURALIZATION_KEYS = %w[zero one two few many other]
  ENGLISH_KEYS = %w[one other]

  EXEMPTED_DOUBLE_CURLY_BRACKET_KEYS = %w[
    js.discourse_automation.scriptables.auto_responder.fields.word_answer_list.description
    discourse_automation.scriptables.email_on_flagged_post.default_template
    js.discourse_ai.discourse_workflows.ai_agent.upload_ids_placeholder
  ]

  INVALID_INTERPOLATION_KEY_REGEX = /%\{[^a-zA-Z\s]+\}|\{\{[^a-zA-Z\s]+\}\}/

  CORE_LOCALES_DIR = File.expand_path("../config/locales", __dir__)

  def initialize(filename, english: nil)
    @filename = filename
    @locale = File.basename(filename)[/\.([^.]{2,})\.yml\z/, 1]
    @english = english
    @errors = {}
    ERROR_MESSAGES.keys.each { |type| @errors[type] = [] }
  end

  def has_errors?
    @errors[:duplicate_keys] = DuplicateKeyFinder.new.find_duplicates(@filename)

    yaml = Psych.safe_load(File.read(@filename), aliases: true)

    top_level_keys = yaml.is_a?(Hash) ? yaml.keys : []
    if top_level_keys != [@locale]
      @errors[:invalid_top_level_key] << "Expected #{[@locale]}, found #{top_level_keys}"
      return true
    end

    yaml = yaml[@locale]

    validate_interpolation_keys(yaml)
    validate_core_client_sections(yaml)

    if @english
      validate_compatibility(@english, yaml) if !@filename.include?("transliterate")
    else
      validate_pluralizations(yaml)
      validate_content(yaml)
    end

    @errors.any? { |_, value| value.any? }
  rescue StandardError => e
    @errors[:invalid_file_format] = ["Failed to parse #{@filename}: #{e.message}"]
    true
  end

  def print_errors
    puts "", "Errors in #{@filename}".red

    @errors.each do |type, keys|
      next if keys.empty?

      ERROR_MESSAGES[type].split("\n").each { |msg| puts "  #{msg}" }
      keys.each { |key| puts "    * #{key}" }
    end
  end

  private

  def validate_interpolation_keys(yaml)
    return if !yaml.is_a?(Hash)

    each_translation(yaml) do |key, value|
      invalid = value.scan(INVALID_INTERPOLATION_KEY_REGEX).uniq
      @errors[:invalid_interpolation_keys] << "#{key}: #{invalid.join(", ")}" if invalid.any?
    end
  end

  def validate_core_client_sections(yaml)
    return if File.realpath(@filename) != File.join(CORE_LOCALES_DIR, "client.#{@locale}.yml")

    required_sections = @locale == "en" ? %w[js wizard_js] : %w[js]
    required_sections.each do |section|
      @errors[:missing_client_sections] << section if !yaml.is_a?(Hash) || !yaml[section]
    end
  end

  def validate_compatibility(english, translated, parent_key = "")
    return if !english.is_a?(Hash) || !translated.is_a?(Hash)

    english.each do |key, english_value|
      next if !translated.key?(key)

      current_key = parent_key.empty? ? key : "#{parent_key}.#{key}"
      translated_value = translated[key]

      if english_value.class != translated_value.class
        @errors[:incompatible_with_english] << current_key
      elsif Hash === english_value
        validate_compatibility(english_value, translated_value, current_key)
      end
    end
  end

  def each_translation(hash, parent_key = "", &block)
    hash.each do |key, value|
      current_key = parent_key.empty? ? key : "#{parent_key}.#{key}"

      if Hash === value
        each_translation(value, current_key, &block)
      else
        yield(current_key, value.to_s)
      end
    end
  end

  def validate_content(yaml)
    each_translation(yaml) do |key, value|
      @errors[:invalid_relative_links] << key if value.match?(%r{href\s*=\s*["']/[^/]|\]\(/[^/]}i)

      @errors[:invalid_relative_image_sources] << key if value.match?(%r{src\s*=\s*["']/[^/]}i)

      if value.match?(/{{(?!settings?:).+?}}/)
        exempt = key.end_with?("_MF") || EXEMPTED_DOUBLE_CURLY_BRACKET_KEYS.include?(key)
        @errors[:invalid_interpolation_key_format] << key unless exempt
      end

      if value
           .enum_for(:scan, SETTING_LINK_START_REGEX)
           .map { Regexp.last_match.begin(0) }
           .any? { |start| !value[start..].match?(VALID_SETTING_LINK_AT_START_REGEX) }
        @errors[:invalid_setting_link_format] << key
      end

      BANNED_PHRASES.keys.each do |banned|
        @errors["banned_phrase_#{banned}"] << key if value.downcase.include?(banned.downcase)
      end
    end
  end

  def each_pluralization(hash, parent_key = "", &block)
    hash.each do |key, value|
      if Hash === value
        current_key = parent_key.empty? ? key : "#{parent_key}.#{key}"
        each_pluralization(value, current_key, &block)
      elsif PLURALIZATION_KEYS.include? key
        yield(parent_key, hash)
      end
    end
  end

  def validate_pluralizations(yaml)
    if !yaml.is_a?(Hash)
      @errors[:wrong_pluralization_keys] << ["Root of the locale file must be a hash"]
      return
    end
    each_pluralization(yaml) do |key, hash|
      # ignore errors from some ActiveRecord messages
      next if key.include?("messages.restrict_dependent_destroy")

      @errors[:wrong_pluralization_keys] << key if hash.keys.sort != ENGLISH_KEYS

      one_value = hash["one"]
      if one_value && one_value.include?("1") && !one_value.match?(/%{count}|{{count}}/)
        @errors[:invalid_one_keys] << key
      end
    end
  end
end

I18nLinter.new(ARGV).run if $PROGRAM_NAME == __FILE__

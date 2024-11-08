# frozen_string_literal: true

require "i18n/i18n_interpolation_keys_finder"
require "yaml"

class LocaleFileChecker
  TYPE_MISSING_INTERPOLATION_KEYS = 1
  TYPE_UNSUPPORTED_INTERPOLATION_KEYS = 2
  TYPE_MISSING_PLURAL_KEYS = 3
  TYPE_INVALID_MESSAGE_FORMAT = 4
  TYPE_INVALID_MARKDOWN_LINK = 5

  def check(locale)
    @errors = {}
    @locale = locale.to_s

    locale_files.each do |locale_path|
      next unless reference_path = reference_file(locale_path)

      @relative_locale_path =
        Pathname.new(locale_path).relative_path_from(Pathname.new(Rails.root)).to_s
      @locale_yaml = YAML.load_file(locale_path, aliases: true)
      @reference_yaml = YAML.load_file(reference_path, aliases: true)

      next if @locale_yaml.blank? || @locale_yaml.first[1].blank?

      check_interpolation_keys
      check_plural_keys
      check_message_format
      check_markdown_links
    end

    @errors
  end

  private

  YML_DIRS = %w[config/locales plugins/**/locales].freeze
  PLURALS_FILE = "config/locales/plurals.rb"
  REFERENCE_LOCALE = "en"
  REFERENCE_PLURAL_KEYS = %w[one other].freeze

  # Some languages should always use %{count} in pluralized strings.
  # https://meta.discourse.org/t/always-use-count-variable-when-translating-pluralized-strings/83969
  FORCE_PLURAL_COUNT_LOCALES = %w[bs fr lt lv ru sl sr uk].freeze

  def locale_files
    YML_DIRS.map { |dir| Dir["#{Rails.root}/#{dir}/{client,server}.#{@locale}.yml"] }.flatten
  end

  def reference_file(path)
    path = path.gsub(/\.\w{2,}\.yml\z/, ".#{REFERENCE_LOCALE}.yml")
    path if File.exist?(path)
  end

  def traverse_hash(hash, parent_keys, &block)
    hash.each do |key, value|
      keys = parent_keys.dup << key

      if value.is_a?(Hash)
        traverse_hash(value, keys, &block)
      else
        yield(keys, value, hash)
      end
    end
  end

  def check_interpolation_keys
    traverse_hash(@locale_yaml, []) do |keys, value|
      reference_value = reference_value(keys)
      next if reference_value.nil?

      if pluralized = reference_value_pluralized?(reference_value)
        if keys.last == "one" && !FORCE_PLURAL_COUNT_LOCALES.include?(@locale)
          reference_value = reference_value["one"]
        else
          reference_value = reference_value["other"]
        end
      end

      reference_interpolation_keys = I18nInterpolationKeysFinder.find(reference_value.to_s)
      locale_interpolation_keys = I18nInterpolationKeysFinder.find(value.to_s)

      missing_keys = reference_interpolation_keys - locale_interpolation_keys
      unsupported_keys = locale_interpolation_keys - reference_interpolation_keys

      # English strings often don't use the %{count} variable within the "one" key,
      # but it's perfectly fine for other locales to use it.
      unsupported_keys.delete("count") if pluralized && keys.last == "one"

      # Not all locales need the %{count} variable within the "one" key.
      if pluralized && keys.last == "one" && !FORCE_PLURAL_COUNT_LOCALES.include?(@locale)
        missing_keys.delete("count")
      end

      unless missing_keys.empty?
        add_error(keys, TYPE_MISSING_INTERPOLATION_KEYS, missing_keys, pluralized: pluralized)
      end
      unless unsupported_keys.empty?
        add_error(
          keys,
          TYPE_UNSUPPORTED_INTERPOLATION_KEYS,
          unsupported_keys,
          pluralized: pluralized,
        )
      end
    end
  end

  def check_markdown_links
    traverse_hash(@locale_yaml, []) do |keys, value|
      next if value.is_a?(Array)

      if /\[.*?\]\s+\(.*?\)/.match?(value)
        add_error(keys, TYPE_INVALID_MARKDOWN_LINK, nil, pluralized: false)
      end
    end
  end

  def check_plural_keys
    known_parent_keys = Set.new

    traverse_hash(@locale_yaml, []) do |keys, _, parent|
      keys = keys[0..-2]
      parent_key = keys.join(".")
      next if known_parent_keys.include?(parent_key)
      known_parent_keys << parent_key

      reference_value = reference_value(keys)
      next if reference_value.nil? || !reference_value_pluralized?(reference_value)

      expected_plural_keys = plural_keys[@locale]
      actual_plural_keys = parent.is_a?(Hash) ? parent.keys : []
      missing_plural_keys = expected_plural_keys - actual_plural_keys

      unless missing_plural_keys.empty?
        add_error(keys, TYPE_MISSING_PLURAL_KEYS, missing_plural_keys, pluralized: true)
      end
    end
  end

  def check_message_format
    require "messageformat"

    traverse_hash(@locale_yaml, []) do |keys, value|
      next unless keys.last.ends_with?("_MF")

      begin
        MessageFormat.compile(@locale, { key: value }, strict: true)
      rescue MessageFormat::Compiler::CompileError => e
        add_error(keys, TYPE_INVALID_MESSAGE_FORMAT, e.cause.message, pluralized: false)
      end
    end
  end

  def reference_value(keys)
    value = @reference_yaml[REFERENCE_LOCALE]

    keys[1..-2].each do |key|
      value = value[key]
      return nil if value.nil?
    end

    reference_value_pluralized?(value) ? value : value[keys.last]
  end

  def reference_value_pluralized?(value)
    value.is_a?(Hash) && value.keys.sort == REFERENCE_PLURAL_KEYS &&
      value.keys.all? { |k| value[k].is_a?(String) }
  end

  def plural_keys
    @plural_keys ||=
      begin
        # rubocop:disable Security/Eval
        eval(File.read("#{Rails.root}/#{PLURALS_FILE}"))
          .map { |locale, value| [locale.to_s, value[:i18n][:plural][:keys].map(&:to_s)] }
          .to_h
      end
  end

  def add_error(keys, type, details, pluralized:)
    @errors[@relative_locale_path] ||= []

    if pluralized
      joined_key = keys[1..-2].join(".") << " [#{keys.last}]"
    else
      joined_key = keys[1..-1].join(".")
    end

    @errors[@relative_locale_path] << { key: joined_key, type: type, details: details.to_s }
  end
end

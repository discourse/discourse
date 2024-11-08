# frozen_string_literal: true

require "colored2"
require "psych"

class I18nLinter
  def initialize(filenames_or_patterns)
    @filenames = filenames_or_patterns.map { |fp| Dir[fp] }.flatten
    @errors = {}
  end

  def run
    has_errors = false

    @filenames.each do |filename|
      validator = LocaleFileValidator.new(filename)

      if validator.has_errors?
        validator.print_errors
        has_errors = true
      end
    end

    exit 1 if has_errors
  end
end

class LocaleFileValidator
  ERROR_MESSAGES = {
    invalid_relative_links:
      "The following keys have relative links, but do not start with %{base_url} or %{base_path}:",
    invalid_relative_image_sources:
      "The following keys have relative image sources, but do not start with %{base_url} or %{base_path}:",
    invalid_interpolation_key_format:
      "The following keys use {{key}} instead of %{key} for interpolation keys:",
    wrong_pluralization_keys:
      "Pluralized strings must have only the sub-keys 'one' and 'other'.\nThe following keys have missing or additional keys:",
    invalid_one_keys:
      "The following keys contain the number 1 instead of the interpolation key %{count}:",
  }.freeze

  PLURALIZATION_KEYS = %w[zero one two few many other].freeze
  ENGLISH_KEYS = %w[one other].freeze

  EXEMPTED_DOUBLE_CURLY_BRACKET_KEYS = [
    "js.discourse_automation.scriptables.auto_responder.fields.word_answer_list.description",
  ].freeze

  def initialize(filename)
    @filename = filename
    @errors = {}
  end

  def has_errors?
    yaml = Psych.safe_load(File.read(@filename), aliases: true)
    yaml = yaml[yaml.keys.first]

    validate_pluralizations(yaml)
    validate_content(yaml)

    @errors.any? { |_, value| value.any? }
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
    @errors[:invalid_relative_links] = []
    @errors[:invalid_relative_image_sources] = []
    @errors[:invalid_interpolation_key_format] = []

    each_translation(yaml) do |key, value|
      @errors[:invalid_relative_links] << key if value.match?(%r{href\s*=\s*["']/[^/]|\]\(/[^/]}i)

      @errors[:invalid_relative_image_sources] << key if value.match?(%r{src\s*=\s*["']/[^/]}i)

      if value.match?(/{{.+?}}/) && !key.end_with?("_MF") &&
           !EXEMPTED_DOUBLE_CURLY_BRACKET_KEYS.include?(key)
        @errors[:invalid_interpolation_key_format] << key
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
    @errors[:wrong_pluralization_keys] = []
    @errors[:invalid_one_keys] = []

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

I18nLinter.new(ARGV).run

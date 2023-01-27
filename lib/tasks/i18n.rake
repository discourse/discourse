# frozen_string_literal: true

require "i18n/locale_file_checker"
require "seed_data/categories"
require "seed_data/topics"
require "colored2"

desc "Checks locale files for errors"
task "i18n:check" => [:environment] do |_, args|
  failed_locales = []

  if args.extras.present?
    locales = []

    args.extras.each do |locale|
      if LocaleSiteSetting.valid_value?(locale)
        locales << locale
      else
        puts "ERROR: #{locale} is not a valid locale"
        exit 1
      end
    end
  else
    locales = LocaleSiteSetting.supported_locales
  end

  locales.each do |locale|
    begin
      all_errors = LocaleFileChecker.new.check(locale)
    rescue StandardError
      failed_locales << locale
      next
    end

    all_errors.each do |filename, errors|
      puts "", "=" * 80
      puts filename.bold
      puts "=" * 80

      errors.each do |error|
        message =
          case error[:type]
          when LocaleFileChecker::TYPE_MISSING_INTERPOLATION_KEYS
            "Missing interpolation keys".red
          when LocaleFileChecker::TYPE_UNSUPPORTED_INTERPOLATION_KEYS
            "Unsupported interpolation keys".red
          when LocaleFileChecker::TYPE_MISSING_PLURAL_KEYS
            "Missing plural keys".magenta
          when LocaleFileChecker::TYPE_INVALID_MESSAGE_FORMAT
            "Invalid message format".yellow
          when LocaleFileChecker::TYPE_INVALID_MARKDOWN_LINK
            "Invalid markdown links".yellow
          end
        details = error[:details].present? ? ": #{error[:details]}" : ""

        puts error[:key] << " -- " << message << details
      end
    end
  end

  failed_locales.each do |failed_locale|
    puts "", "Failed to check locale files for #{failed_locale}".red
  end

  puts ""
  exit 1 unless failed_locales.empty?
end

desc "Update seeded topics and categories with latest translations"
task "i18n:reseed", [:locale] => [:environment] do |_, args|
  locale = args[:locale]&.to_sym

  if locale.blank? || !I18n.locale_available?(locale)
    puts "ERROR: Expecting rake i18n:reseed[locale]"
    exit 1
  end

  SeedData::Categories.new(locale).update
  SeedData::Topics.new(locale).update
end

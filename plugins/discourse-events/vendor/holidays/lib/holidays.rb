## encoding: utf-8
$:.unshift File.dirname(__FILE__)

require 'date'
require 'digest/md5'
require 'holidays/factory/definition'
require 'holidays/factory/date_calculator'
require 'holidays/factory/finder'
require 'holidays/errors'
require 'holidays/load_all_definitions'

module Holidays
  WEEKS = {:first => 1, :second => 2, :third => 3, :fourth => 4, :fifth => 5, :last => -1, :second_last => -2, :third_last => -3}
  MONTH_LENGTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  DAY_SYMBOLS = Date::DAYNAMES.collect { |n| n.downcase.intern }

  DEFINITIONS_PATH = 'generated_definitions'
  FULL_DEFINITIONS_PATH = File.expand_path(File.dirname(__FILE__) + "/#{DEFINITIONS_PATH}")

  class << self
    def any_holidays_during_work_week?(date, *options)
      monday = date - (date.wday - 1)
      friday = date + (5 - date.wday)

      holidays = between(monday, friday, *options)

      holidays && holidays.count > 0
    end

    def on(date, *options)
      between(date, date, *options)
    end

    def between(start_date, end_date, *options)
      raise ArgumentError unless start_date && end_date

      # remove the timezone
      start_date = start_date.new_offset(0) + start_date.offset if start_date.respond_to?(:new_offset)
      end_date = end_date.new_offset(0) + end_date.offset if end_date.respond_to?(:new_offset)

      start_date, end_date = get_date(start_date), get_date(end_date)

      raise ArgumentError if end_date < start_date

      if cached_holidays = Factory::Definition.cache_repository.find(start_date, end_date, options)
        return cached_holidays
      end

      Factory::Finder.between.call(start_date, end_date, options)
    end

    #FIXME All other methods start with a date and require a date. For the next
    #      major version bump we should take the opportunity to change this
    #      signature to match, e.g. next_holidays(from_date, count, options)
    def next_holidays(holidays_count, options, from_date = Date.today)
      raise ArgumentError unless holidays_count
      raise ArgumentError if options.empty?
      raise ArgumentError unless options.is_a?(Array)

      # remove the timezone
      from_date = from_date.new_offset(0) + from_date.offset if from_date.respond_to?(:new_offset)

      from_date = get_date(from_date)

      Factory::Finder.next_holiday.call(holidays_count, from_date, options)
    end

    #FIXME All other methods start with a date and require a date. For the next
    #      major version bump we should take the opportunity to change this
    #      signature to match, e.g. year_holidays(from_date, options)
    def year_holidays(options, from_date = Date.today)
      raise ArgumentError if options.empty?
      raise ArgumentError unless options.is_a?(Array)

      # remove the timezone
      from_date = from_date.new_offset(0) + from_date.offset if from_date.respond_to?(:new_offset)
      from_date = get_date(from_date)

      Factory::Finder.year_holiday.call(from_date, options)
    end

    def cache_between(start_date, end_date, *options)
      start_date, end_date = get_date(start_date), get_date(end_date)
      cache_data = between(start_date, end_date, *options)

      Factory::Definition.cache_repository.cache_between(start_date, end_date, cache_data, options)
    end

    def available_regions
      Holidays::REGIONS
    end

    def load_custom(*files)
      regions, rules_by_month, custom_methods, _ = Factory::Definition.file_parser.parse_definition_files(files)

      custom_methods.each do |method_key, method_entity|
        custom_methods[method_key] = Factory::Definition.custom_method_proc_decorator.call(method_entity)
      end

      Factory::Definition.merger.call(regions, rules_by_month, custom_methods)

      rules_by_month
    end

    def load_all
      path = FULL_DEFINITIONS_PATH + "/"

      Dir.foreach(path) do |item|
        next if item == '.' or item == '..'

        target = path+item
        next if File.extname(target) != '.rb'

        require target
      end
    end

    private

    def get_date(date)
      if date.respond_to?(:to_date)
        date.to_date
      else
        Date.civil(date.year, date.mon, date.mday)
      end
    end
  end
end

Holidays::LoadAllDefinitions.call

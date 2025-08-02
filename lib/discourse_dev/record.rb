# frozen_string_literal: true

require "discourse_dev"
require "rails"
require "faker"

module DiscourseDev
  class Record
    DEFAULT_COUNT = 30.freeze
    AUTO_POPULATED = "auto_populated"

    attr_reader :model, :type

    def initialize(model, count = DEFAULT_COUNT)
      @@initialized ||=
        begin
          Faker::Discourse.unique.clear
          RateLimiter.disable
          true
        end

      @model = model
      @type = model.to_s.downcase.to_sym
      @count = count
    end

    def create!
      record = model.create!(data)
      record.custom_fields[AUTO_POPULATED] = true if record.respond_to?(:custom_fields)
      yield(record) if block_given?
      DiscourseEvent.trigger(:after_create_dev_record, record, type)
      record
    end

    def populate!(ignore_current_count: false)
      unless Discourse.allow_dev_populate?
        raise 'To run this rake task in a production site, set the value of `ALLOW_DEV_POPULATE` environment variable to "1"'
      end

      if !ignore_current_count && !@ignore_current_count
        if current_count >= @count
          puts "Already have #{current_count} #{type} records"

          Rake.application.top_level_tasks.each { |task_name| Rake::Task[task_name].reenable }

          Rake::Task["dev:repopulate"].invoke
          return
        elsif current_count > 0
          @count -= current_count
          puts "There are #{current_count} #{type} records. Creating #{@count} more."
        else
          puts "Creating #{@count} sample #{type} records"
        end
      end

      records = []
      @count.times do
        records << create!
        putc "." unless type == :post
      end

      puts unless type == :post
      DiscourseEvent.trigger(:after_populate_dev_records, records, type)
      records
    end

    def current_count
      model.count
    end

    def self.populate!(**args)
      self.new(**args).populate!
    end

    def self.random(model, use_existing_records: true)
      if !use_existing_records && model.new.respond_to?(:custom_fields)
        model.joins(:_custom_fields).where(
          "#{model.to_s.underscore}_custom_fields.name = '#{AUTO_POPULATED}'",
        )
      end
      count = model.count
      raise "#{model} records are not yet populated" if count == 0

      offset = Faker::Number.between(from: 0, to: count - 1)
      model.offset(offset).first
    end
  end
end

# frozen_string_literal: true

require 'discourse_dev'
require 'rails'
require 'faker'

module DiscourseDev
  class Record
    DEFAULT_COUNT = 30.freeze

    attr_reader :model, :type

    def initialize(model, count = DEFAULT_COUNT)
      @@initialized ||= begin
        Faker::Discourse.unique.clear
        RateLimiter.disable
        true
      end

      @model = model
      @type = model.to_s
      @count = count
    end

    def create!
      record = model.create!(data)
      yield(record) if block_given?
    end

    def populate!
      if current_count >= @count
        puts "Already have #{current_count} #{type.downcase} records"

        Rake.application.top_level_tasks.each do |task_name|
          Rake::Task[task_name].reenable
        end

        Rake::Task['dev:repopulate'].invoke
        return
      elsif current_count > 0
        @count -= current_count
        puts "There are #{current_count} #{type.downcase} records. Creating #{@count} more."
      else
        puts "Creating #{@count} sample #{type.downcase} records"
      end

      @count.times do
        create!
        putc "."
      end

      puts
    end

    def current_count
      model.count
    end

    def self.populate!
      self.new.populate!
    end

    def self.random(model)
      offset = Faker::Number.between(from: 0, to: model.count - 1)
      model.offset(offset).first
    end
  end
end

# frozen_string_literal: true

require 'discourse_dev/record'
require 'rails'
require 'faker'

module DiscourseDev
  class Tag < Record

    def initialize
      super(::Tag, DiscourseDev.config.tag[:count])
    end

    def create!
      super
    rescue ActiveRecord::RecordInvalid => e
      # If the name is taken, try again
      retry
    end

    def populate!
      return unless SiteSetting.tagging_enabled
      super
    end

    def data
      {
        name: Faker::Discourse.unique.tag,
      }
    end
  end
end

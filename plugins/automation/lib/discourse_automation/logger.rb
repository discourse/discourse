# frozen_string_literal: true

module DiscourseAutomation
  module Logger
    PREFIX = "[discourse-automation]"

    def self.warn(message)
      Rails.logger.warn("#{PREFIX} #{message}")
    end

    def self.error(message)
      Rails.logger.error("#{PREFIX} #{message}")
    end

    def self.info(message)
      Rails.logger.info("#{PREFIX} #{message}")
    end
  end
end

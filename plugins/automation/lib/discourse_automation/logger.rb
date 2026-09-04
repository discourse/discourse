# frozen_string_literal: true

module DiscourseAutomation
  module Logger
    PREFIX = "[discourse-automation]"

    class << self
      def warn(message)
        Rails.logger.warn("#{PREFIX} #{message}")
      end

      def error(message)
        Rails.logger.error("#{PREFIX} #{message}")
      end

      def info(message)
        Rails.logger.info("#{PREFIX} #{message}")
      end
    end
  end
end

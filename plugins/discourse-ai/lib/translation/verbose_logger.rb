# frozen_string_literal: true

module DiscourseAi
  module Translation
    class VerboseLogger
      class << self
        def log(message, opts = { level: :warn })
          if SiteSetting.ai_translation_verbose_logs
            Rails.logger.send(opts[:level], "DiscourseAi::Translation: #{message}")
          end
        end
      end
    end
  end
end

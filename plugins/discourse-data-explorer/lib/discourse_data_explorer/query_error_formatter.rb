# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryErrorFormatter
    def self.message(error)
      return "#{error.class}: #{error.message}" unless error.is_a?(ActiveRecord::StatementInvalid)

      database_error_class = error.cause&.class || error.class
      error.message.delete_prefix("#{database_error_class}:").strip
    end
  end
end

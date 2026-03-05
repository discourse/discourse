# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ExecutionContext
      attr_accessor :token_usage_tracker
      attr_reader :audit_logger, :structured_audit_logger

      def initialize(token_usage_tracker: nil, audit_logger: nil, structured_audit_logger: nil)
        @token_usage_tracker = token_usage_tracker
        @audit_logger = audit_logger
        @structured_audit_logger = structured_audit_logger
      end
    end
  end
end

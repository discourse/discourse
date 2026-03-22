# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    class Manual < Base
      def self.identifier
        "trigger:manual"
      end

      def output
        {}
      end
    end
  end
end

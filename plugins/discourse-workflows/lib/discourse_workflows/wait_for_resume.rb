# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForResume
    attr_reader :type, :message

    def initialize(type:, message:)
      @type = type
      @message = message
    end
  end
end

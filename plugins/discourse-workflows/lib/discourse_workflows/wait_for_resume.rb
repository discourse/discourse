# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForResume < StandardError
    attr_reader :type

    def initialize(type:, message:)
      @type = type
      super(message)
    end
  end
end

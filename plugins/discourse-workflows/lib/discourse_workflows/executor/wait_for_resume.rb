# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class WaitForResume
    attr_reader :waiting_until, :waiting_config

    def initialize(waiting_until: nil, waiting_config: {})
      @waiting_until = waiting_until
      @waiting_config = waiting_config
    end
    end
  end
end

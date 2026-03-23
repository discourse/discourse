# frozen_string_literal: true

module DiscourseWorkflows
  module NodeTypeChecks
    def trigger?
      type.start_with?("trigger:")
    end

    def action?
      type.start_with?("action:")
    end

    def condition?
      type.start_with?("condition:")
    end

    def core?
      type.start_with?("core:")
    end
  end
end

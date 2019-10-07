# frozen_string_literal: true

module DiscourseAutomation
  class WorkflowablesController < ::Admin::AdminController
    def index
      render_json_dump(workflowables: DiscourseAutomation::Workflowable.list)
    end
  end
end

# frozen_string_literal: true

module DiscourseAutomation
  class PlannablesController < ::Admin::AdminController
    def index
      render_json_dump(plannables: DiscourseAutomation::Plannable.list)
    end
  end
end

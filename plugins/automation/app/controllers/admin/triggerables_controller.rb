# frozen_string_literal: true

module DiscourseAutomation
  class TriggerablesController < ::Admin::AdminController
    def index
      render_json_dump(triggerables: DiscourseAutomation::Triggerable.list)
    end
  end
end

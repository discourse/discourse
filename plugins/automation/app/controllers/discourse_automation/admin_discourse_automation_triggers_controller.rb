# frozen_string_literal: true

module DiscourseAutomation
  class AdminDiscourseAutomationTriggersController < ::ApplicationController
    def index
      triggers = [
        { id: 'point-in-time', name: 'Point in time' }
      ]

      render_json_dump(triggers: triggers)
    end
  end
end

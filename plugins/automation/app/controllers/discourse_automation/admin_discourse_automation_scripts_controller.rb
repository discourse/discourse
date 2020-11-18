# frozen_string_literal: true

module DiscourseAutomation
  class AdminDiscourseAutomationScriptsController < ::ApplicationController
    def index
      scripts = DiscourseAutomation::Script
        .all
        .map do |s|
          id = s.to_s.gsub(/^script_/, '')
          {
            id: id,
            name: I18n.t("discourse_automation.scripts.#{id}.title"),
            description: I18n.t("discourse_automation.scripts.#{id}.description"),
            doc: I18n.t("discourse_automation.scripts.#{id}.doc"),
          }
        end

      render_json_dump(scripts: scripts)
    end
  end
end

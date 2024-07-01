# frozen_string_literal: true

module DiscourseAutomation
  class AdminScriptablesController < ::Admin::AdminController
    requires_plugin DiscourseAutomation::PLUGIN_NAME

    def index
      scriptables =
        DiscourseAutomation::Scriptable.all.map do |s|
          id = s.to_s.gsub(/^__scriptable_/, "")
          description_key = "discourse_automation.scriptables.#{id}.description"
          doc_key = "discourse_automation.scriptables.#{id}.doc"

          {
            id: id,
            name:
              I18n.t(
                "discourse_automation.scriptables.#{id}.title",
                default: "Missing translation for discourse_automation.scriptables.#{id}.title",
              ),
            description: I18n.exists?(description_key, :en) ? I18n.t(description_key) : nil,
            doc: I18n.exists?(doc_key, :en) ? I18n.t(doc_key) : nil,
          }
        end

      scriptables.sort_by! { |s| s[:name] }
      render_json_dump(scriptables: scriptables)
    end
  end
end

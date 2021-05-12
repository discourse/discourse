# frozen_string_literal: true

module DiscourseAutomation
  class AutomationSerializer < ApplicationSerializer
    attributes :id
    attributes :name
    attributes :enabled
    attributes :script
    attributes :trigger
    attributes :fields
    attributes :updated_at
    attributes :last_updated_by

    def last_updated_by
      BasicUserSerializer.new(User.find(object.last_updated_by_id), root: false).as_json
    end

    def script
      {
        id: object.script,
        version: scriptable.version,
        name: I18n.t("discourse_automation.scriptables.#{object.script}.title"),
        description: I18n.t("discourse_automation.scriptables.#{object.script}.description"),
        doc: I18n.t("discourse_automation.scriptables.#{object.script}.doc"),
        placeholders: scriptable.placeholders
      }
    end

    def fields
      fields = Array(scriptable.fields).map do |script_field|
        field = object.fields.find_by(name: script_field[:name], component: script_field[:component])
        field || DiscourseAutomation::Field.new(name: script_field[:name], component: script_field[:component])
      end

      ActiveModel::ArraySerializer.new(
        fields,
        each_serializer: DiscourseAutomation::FieldSerializer,
        scope: { scriptable: scriptable }
      ).as_json
    end

    def trigger
      trigger = object.trigger || DiscourseAutomation::Trigger.new
      DiscourseAutomation::TriggerSerializer.new(
        trigger,
        root: false
      ).as_json
    end

    private

    def scriptable
      DiscourseAutomation::Scriptable.new(object)
    end
  end
end

# frozen_string_literal: true

module DiscourseAutomation
  class AutomationSerializer < ApplicationSerializer
    attributes :id
    attributes :name
    attributes :enabled
    attributes :script
    attributes :trigger
    attributes :fields

    def script
      {
        id: object.script,
        version: script_options.script_version,
        name: I18n.t("discourse_automation.scripts.#{object.script}.title"),
        description: I18n.t("discourse_automation.scripts.#{object.script}.description"),
        doc: I18n.t("discourse_automation.scripts.#{object.script}.doc"),
        placeholders: script_options.script_placeholders
      }
    end

    def fields
      fields = script_options.script_fields.map do |script_field|
        field = object.fields.find_by(name: script_field[:name], component: script_field[:component])
        field || DiscourseAutomation::Field.new(name: script_field[:name], component: script_field[:component])
      end

      ActiveModel::ArraySerializer.new(
        fields,
        each_serializer: DiscourseAutomation::FieldSerializer,
        scope: { script_options: script_options }
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

    def script_options
      script_method = DiscourseAutomation::Script
        .instance_methods(false)
        .grep(/^script_#{object.script}/).first

      script = DiscourseAutomation::Script.new(object)
      script.public_send(script_method)
      script
    end
  end
end

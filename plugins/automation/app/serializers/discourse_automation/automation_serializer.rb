# frozen_string_literal: true

module DiscourseAutomation
  class AutomationSerializer < ApplicationSerializer
    attributes :id
    attributes :name
    attributes :enabled
    attributes :script
    attributes :trigger
    attributes :updated_at
    attributes :last_updated_by
    attributes :next_pending_automation_at
    attributes :placeholders

    def last_updated_by
      BasicUserSerializer.new(
        User.find_by(id: object.last_updated_by_id) || Discourse.system_user,
        root: false,
      ).as_json
    end

    def include_next_pending_automation_at?
      object.pending_automations.exists?
    end

    def next_pending_automation_at
      object&.pending_automations&.first&.execute_at
    end

    def placeholders
      scriptable_placeholders =
        DiscourseAutomation
          .filter_by_trigger(scriptable&.placeholders || [], object.trigger)
          .map { |placeholder| placeholder[:name] }
      triggerable_placeholders = triggerable&.placeholders || []

      (scriptable_placeholders + triggerable_placeholders).map do |placeholder|
        placeholder.to_s.gsub(/\s+/, "_").underscore
      end
    end

    def script
      key = "discourse_automation.scriptables"
      doc_key = "#{key}.#{object.script}.doc"
      script_with_trigger_key = "#{key}.#{object.script}_with_#{object.trigger}.doc"

      {
        id: object.script,
        version: scriptable.version,
        name:
          I18n.t(
            "#{key}.#{object.script}.title",
            default: "Missing translation for #{key}.#{object.script}.title",
          ),
        description: I18n.t("#{key}.#{object.script}.description", default: ""),
        doc: I18n.exists?(doc_key, :en) ? I18n.t(doc_key) : nil,
        with_trigger_doc:
          I18n.exists?(script_with_trigger_key, :en) ? I18n.t(script_with_trigger_key) : nil,
        forced_triggerable: scriptable.forced_triggerable,
        not_found: scriptable.not_found,
        templates:
          process_templates(filter_fields_with_priority(scriptable.fields, object.trigger&.to_sym)),
        fields: process_fields(object.fields.where(target: "script")),
      }
    end

    def trigger
      key = "discourse_automation.triggerables"
      doc_key = "#{key}.#{object.trigger}.doc"

      {
        id: object.trigger,
        name:
          I18n.t(
            "#{key}.#{object.trigger}.title",
            default: "Missing translation for #{key}.#{object.trigger}.title",
          ),
        description: I18n.t("#{key}.#{object.trigger}.description", default: ""),
        doc: I18n.exists?(doc_key, :en) ? I18n.t(doc_key) : nil,
        not_found: triggerable&.not_found,
        templates: process_templates(triggerable&.fields || []),
        fields: process_fields(object.fields.where(target: "trigger")),
        settings: triggerable&.settings,
      }
    end

    private

    def filter_fields_with_priority(arr, trigger)
      unique_with_priority = {}

      arr.each do |item|
        name = item[:name]
        if (item[:triggerable]&.to_sym == trigger&.to_sym || item[:triggerable].nil?) &&
             (!unique_with_priority.key?(name) || unique_with_priority[name][:triggerable].nil?)
          unique_with_priority[name] = item
        end
      end

      unique_with_priority.values
    end

    def process_templates(fields)
      ActiveModel::ArraySerializer.new(
        fields,
        each_serializer: DiscourseAutomation::TemplateSerializer,
        scope: {
          automation: object,
        },
      ).as_json
    end

    def process_fields(fields)
      ActiveModel::ArraySerializer.new(
        fields || [],
        each_serializer: DiscourseAutomation::FieldSerializer,
      ).as_json || []
    end

    def scriptable
      object.scriptable
    end

    def triggerable
      object.triggerable
    end
  end
end

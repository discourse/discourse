# frozen_string_literal: true

module DiscourseAutomation
  class AutomationSerializer < ApplicationSerializer
    attribute :id
    attribute :name
    attribute :enabled
    attribute :script
    attribute :trigger
    attribute :updated_at
    attribute :last_updated_by
    attribute :next_pending_automation_at
    attribute :placeholders
    attribute :stats

    def last_updated_by
      BasicUserSerializer.new(object.last_updated_by || Discourse.system_user, root: false).as_json
    end

    def include_next_pending_automation_at?
      object.pending_automations.present?
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
        fields: process_fields(script_fields),
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
        fields: process_fields(trigger_fields),
        settings: triggerable&.settings,
      }
    end

    def include_stats?
      scope&.dig(:stats).present?
    end

    EMPTY_STATS = {
      total_runs: 0,
      total_time: 0,
      average_run_time: 0,
      min_run_time: 0,
      max_run_time: 0,
    }

    def stats
      automation_stats = scope&.dig(:stats, object.id) || {}

      {
        last_day: automation_stats[:last_day] || EMPTY_STATS,
        last_week: automation_stats[:last_week] || EMPTY_STATS,
        last_month: automation_stats[:last_month] || EMPTY_STATS,
        last_run_at: automation_stats[:last_run_at],
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

    def script_fields
      object.fields.select { |f| f.target == "script" }
    end

    def trigger_fields
      object.fields.select { |f| f.target == "trigger" }
    end

    def scriptable
      object.scriptable
    end

    def triggerable
      object.triggerable
    end
  end
end

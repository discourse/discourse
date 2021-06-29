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
      BasicUserSerializer.new(User.find_by(id: object.last_updated_by_id) || Discourse.system_user, root: false).as_json
    end

    def script
      {
        id: object.script,
        version: scriptable.version,
        name: I18n.t("discourse_automation.scriptables.#{object.script}.title"),
        description: I18n.t("discourse_automation.scriptables.#{object.script}.description"),
        doc: I18n.t("discourse_automation.scriptables.#{object.script}.doc"),
        forced_triggerable: scriptable.forced_triggerable,
        not_found: scriptable.not_found
      }
    end

    def trigger
      {
        id: object.trigger,
        name: I18n.t("discourse_automation.triggerables.#{object.trigger}.title"),
        description: I18n.t("discourse_automation.triggerables.#{object.trigger}.description"),
        doc: I18n.t("discourse_automation.triggerables.#{object.trigger}.doc"),
        not_found: triggerable.not_found
      }
    end

    def fields
      process_fields(triggerable, 'trigger') + process_fields(scriptable, 'script')
    end

    private

    def process_fields(target, target_name)
      fields = Array(target.fields).map do |tf|
        object.fields.find_or_initialize_by(name: tf[:name], component: tf[:component])
      end

      ActiveModel::ArraySerializer.new(
        fields,
        each_serializer: DiscourseAutomation::FieldSerializer,
        scope: { target: target, target_name: target_name, placeholders: (scriptable.placeholders || []) + (triggerable.placeholders || []) }
      ).as_json || []
    end

    def scriptable
      DiscourseAutomation::Scriptable.new(object.script)
    end

    def triggerable
      DiscourseAutomation::Triggerable.new(object.trigger)
    end
  end
end

# frozen_string_literal: true

module DiscourseAutomation
  class Automation < ActiveRecord::Base
    self.table_name = 'discourse_automation_automations'

    has_many :fields, class_name: 'DiscourseAutomation::Field', dependent: :delete_all, foreign_key: 'automation_id'
    has_many :pending_automations, class_name: 'DiscourseAutomation::PendingAutomation', dependent: :delete_all, foreign_key: 'automation_id'
    has_many :pending_pms, class_name: 'DiscourseAutomation::PendingPm', dependent: :delete_all, foreign_key: 'automation_id'

    validates :script, presence: true

    MIN_NAME_LENGTH = 5
    MAX_NAME_LENGTH = 30
    validates :name, length: { in: MIN_NAME_LENGTH..MAX_NAME_LENGTH }

    def attach_custom_field(target)
      if ![Topic, Post, User].any? { |m| target.is_a?(m) }
        raise "Expected an instance of Topic/Post/User."
      end

      now = Time.now
      fk = target.custom_fields_fk
      row = {
        fk => target.id,
        name: DiscourseAutomation::CUSTOM_FIELD,
        value: id,
        created_at: now,
        updated_at: now
      }

      relation = "#{target.class.name}CustomField".constantize
      relation.upsert(row, unique_by: "idx_#{target.class.name.downcase}_custom_fields_discourse_automation_unique_id_partial")
    end

    def detach_custom_field(target)
      if ![Topic, Post, User].any? { |m| target.is_a?(m) }
        raise "Expected an instance of Topic/Post/User."
      end

      fk = target.custom_fields_fk
      relation = "#{target.class.name}CustomField".constantize
      relation.where(fk => target.id, name: DiscourseAutomation::CUSTOM_FIELD, value: id).delete_all
    end

    def trigger_field(name)
      field = fields.find_by(target: 'trigger', name: name)
      field ? field.metadata : {}
    end

    def script_field(name)
      field = fields.find_by(target: 'script', name: name)
      field ? field.metadata : {}
    end

    def upsert_field!(name, component, metadata, target: 'script')
      field = fields.find_or_initialize_by(name: name, component: component, target: target)
      field.update!(metadata: metadata)
    end

    def trigger!(context = {})
      if enabled
        triggerable&.on_call&.call(self, serialized_fields)

        scriptable = DiscourseAutomation::Scriptable.new(script)
        scriptable.script.call(context, serialized_fields, self)
      end
    end

    def triggerable
      trigger && DiscourseAutomation::Triggerable.new(trigger)
    end

    def scriptable
      script && DiscourseAutomation::Scriptable.new(script)
    end

    def serialized_fields
      fields
        &.pluck(:name, :metadata)
        &.reduce({}) do |acc, hash|
          name, field = hash
          acc[name] = field
          acc
        end || {}
    end

    def reset!
      pending_automations.delete_all
      pending_pms.delete_all
      scriptable&.on_reset&.call(self)
    end
  end
end

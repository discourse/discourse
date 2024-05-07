# frozen_string_literal: true

module DiscourseAutomation
  class Automation < ActiveRecord::Base
    self.table_name = "discourse_automation_automations"

    has_many :fields,
             class_name: "DiscourseAutomation::Field",
             dependent: :delete_all,
             foreign_key: "automation_id"
    has_many :pending_automations,
             class_name: "DiscourseAutomation::PendingAutomation",
             dependent: :delete_all,
             foreign_key: "automation_id"
    has_many :pending_pms,
             class_name: "DiscourseAutomation::PendingPm",
             dependent: :delete_all,
             foreign_key: "automation_id"

    validates :script, presence: true
    validate :validate_trigger_fields

    after_destroy do |automation|
      UserCustomField.where(name: automation.new_user_custom_field_name).destroy_all
    end

    attr_accessor :running_in_background

    def running_in_background!
      @running_in_background = true
    end

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
        :name => DiscourseAutomation::CUSTOM_FIELD,
        :value => id,
        :created_at => now,
        :updated_at => now,
      }

      relation = "#{target.class.name}CustomField".constantize
      relation.upsert(
        row,
        unique_by:
          "idx_#{target.class.name.downcase}_custom_fields_discourse_automation_unique_id_partial",
      )
    end

    def detach_custom_field(target)
      if ![Topic, Post, User].any? { |m| target.is_a?(m) }
        raise "Expected an instance of Topic/Post/User."
      end

      fk = target.custom_fields_fk
      relation = "#{target.class.name}CustomField".constantize
      relation.where(
        fk => target.id,
        :name => DiscourseAutomation::CUSTOM_FIELD,
        :value => id,
      ).delete_all
    end

    def trigger_field(name)
      field = fields.find_by(target: "trigger", name: name)
      field ? field.metadata : {}
    end

    def has_trigger_field?(name)
      !!fields.find_by(target: "trigger", name: name)
    end

    def script_field(name)
      field = fields.find_by(target: "script", name: name)
      field ? field.metadata : {}
    end

    def upsert_field!(name, component, metadata, target: "script")
      field = fields.find_or_initialize_by(name: name, component: component, target: target)
      field.update!(metadata: metadata)
    end

    def self.deserialize_context(context)
      new_context = ActiveSupport::HashWithIndifferentAccess.new

      context.each do |key, value|
        if key.start_with?("_serialized_")
          new_key = key[12..-1]
          found = nil
          if value["class"] == "Symbol"
            found = value["value"].to_sym
          else
            found = value["class"].constantize.find_by(id: value["id"])
          end
          new_context[new_key] = found
        else
          new_context[key] = value
        end
      end
      new_context
    end

    def self.serialize_context(context)
      new_context = {}
      context.each do |k, v|
        if v.is_a?(Symbol)
          new_context["_serialized_#{k}"] = { "class" => "Symbol", "value" => v.to_s }
        elsif v.is_a?(ActiveRecord::Base)
          new_context["_serialized_#{k}"] = { "class" => v.class.name, "id" => v.id }
        else
          new_context[k] = v
        end
      end
      new_context
    end

    def trigger_in_background!(context = {})
      Jobs.enqueue(
        Jobs::DiscourseAutomation::Trigger,
        automation_id: id,
        context: self.class.serialize_context(context),
      )
    end

    def trigger!(context = {})
      if enabled
        if active_id = DiscourseAutomation.get_active_automation
          Rails.logger.warn(<<~TEXT.strip)
            [automation] potential automations infinite loop detected: skipping automation #{self.id} because automation #{active_id} is still executing.")
          TEXT
          return
        end

        begin
          DiscourseAutomation.set_active_automation(self.id)
          if scriptable.background && !running_in_background
            trigger_in_background!(context)
          else
            triggerable&.on_call&.call(self, serialized_fields)
            scriptable.script.call(context, serialized_fields, self)
          end
        ensure
          DiscourseAutomation.set_active_automation(nil)
        end
      end
    end

    def triggerable
      trigger && @triggerable ||= DiscourseAutomation::Triggerable.new(trigger, self)
    end

    def scriptable
      script && @scriptable ||= DiscourseAutomation::Scriptable.new(script, self)
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
      pending_pms.delete_all
      scriptable&.on_reset&.call(self)
    end

    def new_user_custom_field_name
      "automation_#{self.id}_new_user"
    end

    private

    def validate_trigger_fields
      !triggerable || triggerable.valid?(self)
    end
  end
end

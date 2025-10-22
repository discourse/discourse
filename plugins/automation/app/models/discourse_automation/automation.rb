# frozen_string_literal: true

module DiscourseAutomation
  class Automation < ActiveRecord::Base
    self.table_name = "discourse_automation_automations"

    belongs_to :last_updated_by, class_name: "User", foreign_key: "last_updated_by_id"

    has_many :fields,
             class_name: "DiscourseAutomation::Field",
             dependent: :delete_all,
             foreign_key: "automation_id",
             inverse_of: :automation
    has_many :pending_automations,
             class_name: "DiscourseAutomation::PendingAutomation",
             dependent: :delete_all,
             foreign_key: "automation_id"
    has_many :pending_pms,
             class_name: "DiscourseAutomation::PendingPm",
             dependent: :delete_all,
             foreign_key: "automation_id"
    has_many :stats, class_name: "DiscourseAutomation::Stat", dependent: :delete_all

    validates :script, presence: true
    validate :validate_trigger_fields
    validate :required_fields_complete, if: :perform_required_fields_validation?

    after_destroy do |automation|
      UserCustomField.where(name: automation.new_user_custom_field_name).destroy_all
    end

    attr_accessor :running_in_background
    attr_accessor :perform_required_fields_validation

    def trigger=(new_trigger)
      @triggerable = nil
      super
    end

    def script=(new_script)
      @scriptable = nil
      super
    end

    def running_in_background!
      @running_in_background = true
    end

    MAX_NAME_LENGTH = 100
    validates :name, length: { maximum: MAX_NAME_LENGTH }

    def add_id_to_custom_field(target, custom_field_key)
      if ![Topic, Post, User].any? { |m| target.is_a?(m) }
        raise "Expected an instance of Topic/Post/User."
      end

      change_automation_ids_custom_field_in_mutex(target, custom_field_key) do
        target.reload
        ids = Array(target.custom_fields[custom_field_key])
        if !ids.include?(self.id)
          ids << self.id
          ids = ids.compact.uniq
          target.custom_fields[custom_field_key] = ids
          target.save_custom_fields
        end
      end
    end

    def remove_id_from_custom_field(target, custom_field_key)
      if ![Topic, Post, User].any? { |m| target.is_a?(m) }
        raise "Expected an instance of Topic/Post/User."
      end

      change_automation_ids_custom_field_in_mutex(target, custom_field_key) do
        target.reload
        ids = Array(target.custom_fields[custom_field_key])
        if ids.include?(self.id)
          ids = ids.compact.uniq
          ids.delete(self.id)
          target.custom_fields[custom_field_key] = ids
          target.save_custom_fields
        end
      end
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
        return if active_id = DiscourseAutomation.get_active_automation

        begin
          DiscourseAutomation.set_active_automation(self.id)
          if scriptable.background && !running_in_background
            trigger_in_background!(context)
          else
            Stat.log(id) do
              triggerable&.on_call&.call(self, serialized_fields)
              scriptable.script.call(context, serialized_fields, self)
            end
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

    def change_automation_ids_custom_field_in_mutex(target, key)
      DistributedMutex.synchronize(
        "automation_custom_field_#{key}_#{target.class.table_name}_#{target.id}",
        validity: 5.seconds,
      ) { yield }
    end

    def perform_required_fields_validation?
      !!@perform_required_fields_validation && enabled?
    end

    def required_fields_complete
      if scriptable.blank?
        errors.add(
          :base,
          I18n.t("discourse_automation.models.automations.validations.script_blank"),
        )
        return
      end

      if triggerable.blank?
        errors.add(
          :base,
          I18n.t("discourse_automation.models.automations.validations.trigger_blank"),
        )
        return
      end

      if missing_fields = scriptable.missing_required_fields.presence
        errors.add(
          :base,
          I18n.t(
            "discourse_automation.models.automations.validations.script_missing_required_fields",
            fields: missing_fields.join(", "),
          ),
        )
        return
      end

      if missing_fields = triggerable.missing_required_fields.presence
        errors.add(
          :base,
          I18n.t(
            "discourse_automation.models.automations.validations.trigger_missing_required_fields",
            fields: missing_fields.join(", "),
          ),
        )
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_automation_automations
#
#  id                 :bigint           not null, primary key
#  name               :string
#  script             :string           not null
#  enabled            :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  last_updated_by_id :integer          not null
#  trigger            :string
#

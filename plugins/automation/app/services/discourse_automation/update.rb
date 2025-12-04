# frozen_string_literal: true

class DiscourseAutomation::Update
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :automation_id
  #   @option params [String] :name
  #   @option params [String] :script
  #   @option params [String] :trigger
  #   @option params [Boolean] :enabled
  #   @option params [Array] :fields
  #   @return [Service::Base::Context]

  policy :can_update_automation

  params do
    attribute :automation_id, :integer
    attribute :name, :string
    attribute :script, :string
    attribute :trigger, :string
    attribute :enabled, :boolean
    attribute :fields, :array

    validates :automation_id, presence: true
  end

  model :automation
  step :capture_previous_state

  transaction do
    step :apply_forced_triggerable
    step :handle_trigger_change
    step :handle_script_change
    step :update_automation
    step :log_action
  end

  private

  def can_update_automation(guardian:)
    guardian.is_admin?
  end

  def fetch_automation(params:)
    DiscourseAutomation::Automation.includes(:fields, :pending_automations).find_by(
      id: params.automation_id,
    )
  end

  def capture_previous_state(automation:)
    context[:previous_state] = {
      name: automation.name,
      script: automation.script,
      trigger: automation.trigger,
      enabled: automation.enabled,
      fields: automation.serialized_fields,
    }
  end

  def apply_forced_triggerable(automation:, params:)
    if automation.scriptable&.forced_triggerable
      context[:forced_trigger] = automation.scriptable.forced_triggerable[:triggerable].to_s
    end
  end

  def handle_trigger_change(automation:, params:)
    new_trigger = context[:forced_trigger] || params.trigger
    return if new_trigger.blank?
    return if automation.trigger == new_trigger

    automation.fields.destroy_all
    context[:fields_cleared] = true
    context[:force_disable] = true
  end

  def handle_script_change(automation:, params:)
    return if params.script.blank?
    return if automation.script == params.script

    automation.fields.destroy_all
    context[:fields_cleared] = true
    context[:force_disable] = true
    context[:clear_trigger] = true
  end

  def update_automation(automation:, params:, guardian:)
    automation.perform_required_fields_validation = true

    attributes = { last_updated_by_id: guardian.user.id }
    attributes[:name] = params.name if params.name.present?
    attributes[:script] = params.script if params.script.present?
    attributes[:trigger] = context[:forced_trigger] || params.trigger if params.trigger.present? ||
      context[:forced_trigger].present?
    attributes[:trigger] = nil if context[:clear_trigger]
    attributes[:enabled] = params.enabled unless params.enabled.nil?
    attributes[:enabled] = false if context[:force_disable]

    # Update fields if not cleared and fields provided
    if !context[:fields_cleared] && params.fields.present?
      Array(params.fields)
        .reject(&:empty?)
        .each do |field|
          automation.upsert_field!(
            field[:name],
            field[:component],
            field[:metadata],
            target: field[:target],
          )
        end
    end

    if context[:clear_trigger]
      automation.assign_attributes(attributes)
      automation.save!(validate: false)
    else
      automation.update!(attributes)
    end

    automation.reload
  end

  def log_action(automation:, guardian:)
    previous_state = context[:previous_state]
    changes = {}

    %i[name script trigger enabled].each do |attr|
      current_value = automation.public_send(attr)
      previous_value = previous_state[attr]
      if current_value != previous_value
        changes[attr] = "#{format_value(previous_value)} → #{format_value(current_value)}"
      end
    end

    current_fields = automation.serialized_fields
    previous_fields = previous_state[:fields]

    all_field_names = (current_fields.keys + previous_fields.keys).uniq.sort

    all_field_names.each do |field_name|
      current_field = current_fields[field_name]
      previous_field = previous_fields[field_name]

      next if current_field == previous_field
      next if field_empty?(previous_field) && field_empty?(current_field)

      changes[
        field_name
      ] = "#{format_field_value(previous_field)} → #{format_field_value(current_field)}"
    end

    return if changes.empty?

    details = { id: automation.id }
    # Only show name as identifier if it wasn't changed
    details[:name] = automation.name unless changes.key?(:name)
    details.merge!(changes)

    StaffActionLogger.new(guardian.user).log_custom("update_automation", **details)
  end

  def format_value(value)
    return value.to_s if value.is_a?(TrueClass) || value.is_a?(FalseClass)
    value.blank? ? empty_value : value.to_s
  end

  def field_empty?(field)
    return true if field.blank?
    value = field["value"]
    return false if value.is_a?(TrueClass) || value.is_a?(FalseClass)
    value.blank?
  end

  def format_field_value(field)
    field_empty?(field) ? empty_value : field["value"].to_s
  end

  def empty_value
    @empty_value ||= I18n.t("discourse_automation.staff_action_logs.empty_value")
  end
end

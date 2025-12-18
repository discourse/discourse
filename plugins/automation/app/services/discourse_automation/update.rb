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
  model :previous_state, :capture_previous_state

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
    automation.slice(:name, :script, :trigger, :enabled).merge(fields: automation.serialized_fields)
  end

  def apply_forced_triggerable(automation:)
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

    attributes =
      params
        .slice(:name, :script)
        .merge(
          last_updated_by_id: guardian.user.id,
          trigger: context[:forced_trigger] || params.trigger,
        )
        .compact_blank
    attributes[:trigger] = nil if context[:clear_trigger]
    attributes[:enabled] = params.enabled unless params.enabled.nil?
    attributes[:enabled] = false if context[:force_disable]

    # Update fields if not cleared and fields provided
    if !context[:fields_cleared] && params.fields.present?
      params.fields.each do |field|
        next if field[:name].blank?
        automation.upsert_field!(
          field[:name],
          field[:component],
          field[:metadata],
          target: field[:target],
        )
      end
    end

    automation.assign_attributes(attributes)
    automation.save!(validate: context[:clear_trigger].blank?)
    automation.reload
  end

  def log_action(automation:, guardian:, previous_state:)
    DiscourseAutomation::Action::LogAutomationUpdate.call(automation, previous_state, guardian)
  end
end

# frozen_string_literal: true

module ReviewableActionBuilder
  extend ActiveSupport::Concern

  # Build a single reviewable action and add it to the provided actions list.
  # This is the canonical API used by both the legacy and refreshed UI code paths.
  #
  # Parameters
  # - actions: Reviewable::Actions instance to add to
  # - id: Symbol for the action, used to derive I18n keys
  # - icon: Ignored in the refreshed UI; accepted for compatibility
  # - button_class: Optional CSS class for buttons in clients that render it
  # - bundle: Optional bundle object returned by add_bundle to group actions
  # - client_action: Optional client-side action identifier (e.g. "edit")
  # - confirm: When true, uses "reviewables.actions.<id>.confirm" for confirm_message
  # - confirm_message: Optional explicit confirm message key to override the default
  # - label: Optional explicit label key to override the default
  # - description: Optional explicit description key to override the default
  # - require_reject_reason: When true, requires a rejection reason for the action
  def build_action(
    actions,
    id,
    icon: nil,
    button_class: nil,
    bundle: nil,
    client_action: nil,
    confirm: false,
    confirm_message: nil,
    label: nil,
    description: nil,
    require_reject_reason: false
  )
    actions.add(id, bundle: bundle) do |action|
      prefix = "reviewables.actions.#{id}"
      action.icon = icon if icon
      action.button_class = button_class if button_class
      action.label = label || "#{prefix}.title"
      action.description = description || "#{prefix}.description"
      action.client_action = client_action if client_action
      action.confirm_message = confirm_message if confirm_message
      action.confirm_message = "#{prefix}.confirm" if confirm && confirm_message.nil?
      action.require_reject_reason = require_reject_reason
    end
  end
end

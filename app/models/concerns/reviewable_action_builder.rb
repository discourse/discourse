# frozen_string_literal: true

module ReviewableActionBuilder
  extend ActiveSupport::Concern

  # Build a single reviewable action and add it to the provided actions list.
  # This is the canonical API used by both the legacy and refreshed UI code paths.
  #
  # @param {Reviewable::Actions} actions - actions instance to add to.
  # @param {Symbol} id - Symbol for the action, used to derive I18n keys.
  # @param {String} icon - Optional name of the icon to display with the action. Ignored in the refreshed UI.
  # @param {String} button_class - Optional CSS class for buttons in clients that render it.
  # @param {Reviewable::Actions::Bundle} bundle - Optional bundle object returned by add_bundle to group actions.
  # @param {String} client_action - Optional client-side action identifier (e.g. "edit").
  # @param {Boolean} confirm - When true, uses "reviewables.actions.<id>.confirm" for confirm_message.
  # @param {Boolean} require_reject_reason - When true, requires a rejection reason for the action.
  def build_action(
    actions,
    id,
    icon: nil,
    button_class: nil,
    bundle: nil,
    client_action: nil,
    confirm: false,
    require_reject_reason: false
  )
    actions.add(id, bundle: bundle) do |action|
      prefix = "reviewables.actions.#{id}"
      action.icon = icon if icon
      action.button_class = button_class if button_class
      action.label = "#{prefix}.title"
      action.description = "#{prefix}.description"
      action.client_action = client_action if client_action
      action.confirm_message = "#{prefix}.confirm" if confirm
      action.completed_message = "#{prefix}.complete"
      action.require_reject_reason = require_reject_reason
    end
  end
end

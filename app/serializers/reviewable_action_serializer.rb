# frozen_string_literal: true

class ReviewableActionSerializer < ApplicationSerializer
  attributes :id,
             :action_name,
             :icon,
             :button_class,
             :label,
             :confirm_message,
             :confirm_destructive,
             :description,
             :server_action,
             :client_action,
             :require_reject_reason,
             :completed_message

  def label
    I18n.t(object.label)
  end

  def confirm_message
    I18n.t(object.confirm_message, **(object.confirm_message_args || {}))
  end

  def description
    I18n.t(object.description, default: nil)
  end

  def server_action
    object.server_action
  end

  def completed_message
    I18n.t(object.completed_message, default: nil)
  end

  def include_description?
    description.present?
  end

  def include_confirm_message?
    object.confirm_message.present?
  end

  def include_confirm_destructive?
    object.confirm_destructive.present?
  end

  def include_client_action?
    object.client_action.present?
  end

  def include_require_reject_reason?
    object.require_reject_reason.present?
  end
end

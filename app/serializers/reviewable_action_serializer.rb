# frozen_string_literal: true

class ReviewableActionSerializer < ApplicationSerializer
  attributes :id,
             :action_name,
             :icon,
             :button_class,
             :label,
             :confirm_message,
             :confirm_message_template,
             :confirm_destructive,
             :description,
             :server_action,
             :client_action,
             :require_reject_reason,
             :completed_message,
             :penalty_effect,
             :dsa_classification_required

  has_one :confirm_user, serializer: BasicUserSerializer, root: "users"

  def label
    I18n.t(object.label)
  end

  def confirm_message
    I18n.t(object.confirm_message, **confirmation_args)
  end

  def confirm_message_template
    I18n.t(object.confirm_message, **confirmation_args.merge(user: "%{user}"))
  end

  def include_confirm_user?
    object.confirm_user.present?
  end

  alias_method :include_confirm_message_template?, :include_confirm_user?

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

  def include_dsa_classification_required?
    object.dsa_classification_required && DsaStatementOfRecord.classification_enabled?
  end

  def include_penalty_effect?
    object.penalty_effect.present?
  end

  private

  def confirmation_args
    args = object.confirm_message_args || {}
    return args unless object.confirm_user

    username = ERB::Util.html_escape(args[:username])
    args.merge(username: username, user: "@#{username}")
  end
end

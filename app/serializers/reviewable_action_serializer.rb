# frozen_string_literal: true

class ReviewableActionSerializer < ApplicationSerializer
  attributes :id, :icon, :button_class, :label, :confirm_message, :description, :client_action

  def label
    I18n.t(object.label)
  end

  def confirm_message
    I18n.t(object.confirm_message)
  end

  def description
    I18n.t(object.description, default: nil)
  end

  def include_description?
    description.present?
  end

  def include_confirm_message?
    object.confirm_message.present?
  end

  def include_client_action?
    object.client_action.present?
  end

end

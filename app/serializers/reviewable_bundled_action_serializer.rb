# frozen_string_literal: true

class ReviewableBundledActionSerializer < ApplicationSerializer
  attributes :id, :icon, :label
  has_many :actions, serializer: ReviewableActionSerializer, root: 'actions'

  def label
    I18n.t(object.label, default: nil)
  end

  def include_label?
    label.present?
  end

  def include_icon?
    icon.present?
  end
end

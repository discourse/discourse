# frozen_string_literal: true

class UserFieldSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :field_type,
             :editable,
             :required,
             :requirement,
             :show_on_profile,
             :show_on_user_card,
             :searchable,
             :position,
             :options

  def required
    object.required?
  end

  def options
    object.user_field_options.pluck(:value)
  end

  def include_options?
    options.present?
  end
end

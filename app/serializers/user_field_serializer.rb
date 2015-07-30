class UserFieldSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :field_type,
             :editable,
             :required,
             :show_on_profile,
             :position,
             :options

  def options
    object.user_field_options.pluck(:value)
  end

  def include_options?
    options.present?
  end
end

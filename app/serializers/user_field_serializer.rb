class UserFieldSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :field_type,
             :editable,
             :required,
             :show_on_profile
end

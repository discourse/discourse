class UserFieldSerializer < ApplicationSerializer
  attributes :id, :name, :description, :field_type, :editable
end

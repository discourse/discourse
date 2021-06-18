# frozen_string_literal: true

class DirectoryColumnSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :type,
             :position,
             :icon,
             :user_field_id

  def name
    object.name || object.user_field.name
  end
end

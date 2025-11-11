# frozen_string_literal: true

class AiFeaturesPersonaSerializer < ApplicationSerializer
  attributes :id, :name, :allowed_groups

  def allowed_groups
    Group
      .where(id: object.allowed_group_ids)
      .pluck(:id, :name)
      .map { |id, name| { id: id, name: name } }
  end
end

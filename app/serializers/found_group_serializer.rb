# frozen_string_literal: true

class FoundGroupSerializer < ApplicationSerializer
  attributes :id, :automatic, :name, :full_name, :display_name

  def display_name
    if object.automatic
      auto_group_name = Group::AUTO_GROUP_IDS[object.id]
      I18n.t("groups.default_full_names.#{auto_group_name}")
    else
      object.full_name || object.name
    end
  end
end

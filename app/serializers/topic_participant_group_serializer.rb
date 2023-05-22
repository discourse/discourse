# frozen_string_literal: true

class TopicParticipantGroupSerializer < ApplicationSerializer
  attributes :id, :name, :title, :full_name, :display_name

  def include_display_name?
    object.automatic
  end

  def display_name
    if auto_group_name = Group::AUTO_GROUP_IDS[object.id]
      I18n.t("groups.default_names.#{auto_group_name}")
    end
  end
end

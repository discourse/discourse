# frozen_string_literal: true

class SidebarTagSerializer < ApplicationSerializer
  attributes :name, :description, :pm_only

  def name
    modified =
      DiscoursePluginRegistry.apply_modifier(:sidebar_tag_serializer_name, object.name, self)
    modified || object.name
  end

  def pm_only
    topic_count_column = Tag.topic_count_column(scope)
    object.public_send(topic_count_column) == 0 && object.pm_topic_count > 0
  end
end

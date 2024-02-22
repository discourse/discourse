# frozen_string_literal: true

class SidebarTagSerializer < ApplicationSerializer
  attributes :name, :description, :pm_only

  def pm_only
    topic_count_column = Tag.topic_count_column(scope)
    object.public_send(topic_count_column) == 0 && object.pm_topic_count > 0
  end
end

# frozen_string_literal: true

class SidebarTagSerializer < ApplicationSerializer
  attributes :id, :name, :slug, :description, :pm_only

  def slug
    object.slug_for_url
  end

  def pm_only
    topic_count_column = Tag.topic_count_column(scope)
    object.public_send(topic_count_column) == 0 && object.pm_topic_count > 0
  end
end

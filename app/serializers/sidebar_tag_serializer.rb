# frozen_string_literal: true

class SidebarTagSerializer < ApplicationSerializer
  attributes :id, :name, :slug, :description, :pm_only

  def name
    translated =
      (object.get_localization&.name if ContentLocalization.show_translated_tag?(object, scope))
    translated || object.name
  end

  def description
    translated =
      if ContentLocalization.show_translated_tag?(object, scope)
        object.get_localization&.description
      end
    translated || object.description
  end

  def pm_only
    topic_count_column = Tag.topic_count_column(scope)
    object.public_send(topic_count_column) == 0 && object.pm_topic_count > 0
  end
end

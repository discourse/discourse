# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  attributes :id, :name, :topic_count, :staff, :description

  def name
    modified = DiscoursePluginRegistry.apply_modifier(:tag_serializer_name, object.name, self)
    modified || object.name
  end

  def topic_count
    object.public_send(Tag.topic_count_column(scope))
  end

  def staff
    DiscourseTagging.staff_tag_names.include?(name)
  end
end

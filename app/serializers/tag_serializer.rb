# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  attributes :id, :name, :topic_count, :staff, :description, :groups

  def topic_count
    object.public_send(Tag.topic_count_column(scope))
  end

  def staff
    DiscourseTagging.staff_tag_names.include?(name)
  end

  def groups
    object.visible_tag_groups_names(scope)
  end
end

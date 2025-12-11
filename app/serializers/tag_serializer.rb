# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  attributes :id, :name, :slug, :topic_count, :staff, :description

  def id
    object.id
  end

  def slug
    object.slug_for_url
  end

  def topic_count
    object.public_send(Tag.topic_count_column(scope))
  end

  def staff
    DiscourseTagging.staff_tag_names.include?(name)
  end
end

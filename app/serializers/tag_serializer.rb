# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  root 'tag'

  attributes :id, :name, :topic_count, :staff

  def staff
    DiscourseTagging.staff_tag_names.include?(name)
  end
end

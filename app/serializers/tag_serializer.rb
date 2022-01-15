# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  attributes :id, :name, :topic_count, :staff, :description

  def staff
    DiscourseTagging.staff_tag_names.include?(name)
  end
end

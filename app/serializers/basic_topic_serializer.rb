# frozen_string_literal: true

# The most basic attributes of a topic that we need to create a link for it.
class BasicTopicSerializer < ApplicationSerializer
  attributes :id, :title, :fancy_title, :slug, :posts_count, :last_posted_at

  def fancy_title
    f = object.fancy_title
    modified = DiscoursePluginRegistry.apply_modifier(:topic_serializer_fancy_title, f, self)
    modified || f
  end
end

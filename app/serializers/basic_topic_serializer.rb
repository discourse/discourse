# frozen_string_literal: true

# The most basic attributes of a topic that we need to create a link for it.
class BasicTopicSerializer < ApplicationSerializer
  attributes :id, :title, :fancy_title, :slug, :posts_count

  def fancy_title
    f = object.fancy_title

    if (ContentLocalization.show_translated_topic?(object, scope))
      object.get_localization&.fancy_title.presence || f
    else
      f
    end
  end
end

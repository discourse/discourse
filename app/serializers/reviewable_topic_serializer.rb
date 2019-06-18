# frozen_string_literal: true

class ReviewableTopicSerializer < ApplicationSerializer
  attributes(
    :id,
    :title,
    :fancy_title,
    :slug,
    :archived,
    :closed,
    :visible,
    :archetype,
    :relative_url,
    :stats,
    :reviewable_score
  )

  has_one :claimed_by, serializer: BasicUserSerializer, root: 'users'

  def stats
    @options[:stats][object.id]
  end

  def claimed_by
    @options[:claimed_topics][object.id]
  end

  def include_claimed_by?
    @options[:claimed_topics]
  end

end

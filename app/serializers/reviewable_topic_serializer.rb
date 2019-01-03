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

  def stats
    @options[:stats][object.id]
  end
end

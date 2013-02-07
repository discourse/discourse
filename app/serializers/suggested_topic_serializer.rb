class SuggestedTopicSerializer < BasicTopicSerializer

  attributes :archetype, :slug, :like_count, :views, :last_post_age
  has_one :category, embed: :objects

  def last_post_age
    return nil if object.last_posted_at.blank?
    AgeWords.age_words(Time.now - object.last_posted_at)
  end

end

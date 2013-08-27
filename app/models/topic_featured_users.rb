class TopicFeaturedUsers
  attr_reader :topic

  def initialize(topic)
    @topic = topic
  end

  def self.count
    4
  end

  # Chooses which topic users to feature
  def choose(args={})
    topic.reload unless rails4?
    clear
    update keys(args)
    topic.save
  end

  def user_ids
    [topic.featured_user1_id, 
     topic.featured_user2_id, 
     topic.featured_user3_id, 
     topic.featured_user4_id].uniq.compact
  end

  private

    def keys(args)
      # Don't include the OP or the last poster
      to_feature = topic.posts.where('user_id NOT IN (?, ?)', topic.user_id, topic.last_post_user_id)

      # Exclude a given post if supplied (in the case of deletes)
      to_feature = to_feature.where("id <> ?", args[:except_post_id]) if args[:except_post_id].present?

      # Assign the featured_user{x} columns
      to_feature.group(:user_id).order('count_all desc').limit(TopicFeaturedUsers.count).count.keys
    end

    def clear
      TopicFeaturedUsers.count.times do |i|
        topic.send("featured_user#{i+1}_id=", nil)
      end
    end

    def update(user_keys)
      user_keys.each_with_index do |user_id, i|
        topic.send("featured_user#{i+1}_id=", user_id)
      end
    end
end

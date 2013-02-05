module Jobs

  class FeatureTopicUsers < Jobs::Base

    def execute(args)
      topic = Topic.where(id: args[:topic_id]).first
      raise Discourse::InvalidParameters.new(:topic_id) unless topic.present?

      to_feature = topic.posts

      # Don't include the OP or the last poster
      to_feature = to_feature.where('user_id <> ?', topic.user_id)
      to_feature = to_feature.where('user_id <> ?', topic.last_post_user_id)

      # Exclude a given post if supplied (in the case of deletes)
      to_feature = to_feature.where("id <> ?", args[:except_post_id]) if args[:except_post_id].present?


      # Clear the featured users by default
      Topic::FEATURED_USERS.times do |i|
        topic.send("featured_user#{i+1}_id=", nil)
      end

      # Assign the featured_user{x} columns
      to_feature = to_feature.group(:user_id).order('count_all desc').limit(Topic::FEATURED_USERS)
      to_feature.count.keys.each_with_index do |user_id, i|
        topic.send("featured_user#{i+1}_id=", user_id)
      end

      topic.save
    end

  end

end

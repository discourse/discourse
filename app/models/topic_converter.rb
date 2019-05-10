class TopicConverter

  attr_reader :topic

  def initialize(topic, user)
    @topic = topic
    @user = user
  end

  def convert_to_public_topic(category_id = nil)
    Topic.transaction do
      category_id =
        if category_id
          category_id
        elsif SiteSetting.allow_uncategorized_topics
          SiteSetting.uncategorized_category_id
        else
          Category.where(read_restricted: false)
            .where.not(id: SiteSetting.uncategorized_category_id)
            .order('id asc')
            .pluck(:id).first
        end

      PostRevisor.new(@topic.first_post, @topic).revise!(
        @user,
        category_id: category_id,
        archetype: Archetype.default
      )

      update_user_stats
      Jobs.enqueue(:topic_action_converter, topic_id: @topic.id)

      watch_topic(topic)
    end
    @topic
  end

  def convert_to_private_message
    Topic.transaction do
      @topic.update_category_topic_count_by(-1)

      PostRevisor.new(@topic.first_post, @topic).revise!(
        @user,
        category_id: nil,
        archetype: Archetype.private_message
      )

      add_allowed_users

      Jobs.enqueue(:topic_action_converter, topic_id: @topic.id)
      watch_topic(topic)
    end
    @topic
  end

  private

  def update_user_stats
    @topic.posts.where(deleted_at: nil).each do |p|
      user = User.find(p.user_id)
      # update posts count. NOTE that DirectoryItem.refresh will overwrite this by counting UserAction records.
      user.user_stat.post_count += 1
      user.user_stat.save!
    end
    # update topics count
    @topic.user.user_stat.topic_count += 1
    @topic.user.user_stat.save!
  end

  def add_allowed_users
    @topic.posts.where(deleted_at: nil).each do |p|
      user = User.find(p.user_id)
      @topic.topic_allowed_users.build(user_id: user.id) unless @topic.topic_allowed_users.where(user_id: user.id).exists?
      # update posts count. NOTE that DirectoryItem.refresh will overwrite this by counting UserAction records.
      user.user_stat.post_count -= 1
      user.user_stat.save!
    end
    @topic.topic_allowed_users.build(user_id: @user.id) unless @topic.topic_allowed_users.where(user_id: @user.id).exists?
    # update topics count
    @topic.user.user_stat.topic_count -= 1
    @topic.user.user_stat.save!
    @topic.save!
  end

  def watch_topic(topic)
    @topic.notifier.watch_topic!(topic.user_id)

    @topic.reload.topic_allowed_users.each do |tau|
      next if tau.user_id < 0 || tau.user_id == topic.user_id
      topic.notifier.watch!(tau.user_id)
    end
  end

end

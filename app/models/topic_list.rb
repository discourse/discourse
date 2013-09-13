require_dependency 'avatar_lookup'

class TopicList
  include ActiveModel::Serialization

  attr_accessor :more_topics_url,
                :draft,
                :draft_key,
                :draft_sequence,
                :filter

  def initialize(filter, current_user, topics)
    @filter = filter
    @current_user = current_user
    @topics_input = topics
  end

  # Lazy initialization
  def topics
    return @topics if @topics.present?

    @topics = @topics_input.to_a

    # Attach some data for serialization to each topic
    @topic_lookup = TopicUser.lookup_for(@current_user, @topics) if @current_user.present?

    # Create a lookup for all the user ids we need
    user_ids = []
    @topics.each do |ft|
      user_ids << ft.user_id << ft.last_post_user_id << ft.featured_user_ids
    end

    avatar_lookup = AvatarLookup.new(user_ids)

    @topics.each do |ft|
      ft.user_data = @topic_lookup[ft.id] if @topic_lookup.present?
      ft.posters = ft.posters_summary(avatar_lookup: avatar_lookup)
      ft.topic_list = self
    end

    return @topics
  end

  def topic_ids
    return [] if @topics_input.blank?
    @topics_input.map {|t| t.id}
  end

  def attributes
    {'more_topics_url' => page}
  end

  def has_rank_details?

    # Only moderators can see rank details
    return false unless @current_user && @current_user.staff?

    # Only show them on 'Hot'
    return @filter == :hot
  end
end

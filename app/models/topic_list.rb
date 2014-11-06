require_dependency 'avatar_lookup'

class TopicList
  include ActiveModel::Serialization

  attr_accessor :more_topics_url,
                :prev_topics_url,
                :draft,
                :draft_key,
                :draft_sequence,
                :filter,
                :for_period

  def initialize(filter, current_user, topics, opts=nil)
    @filter = filter
    @current_user = current_user
    @topics_input = topics
    @opts = opts || {}
  end

  def preload_key
    if @opts[:category]
      c = Category.where(id: @opts[:category_id]).first
      return "topic_list_#{c.url.sub(/^\//, '')}/l/#{@filter}" if c
    end

    "topic_list_#{@filter}"
  end

  # Lazy initialization
  def topics
    return @topics if @topics.present?

    # copy side-loaded data (allowed users) before dumping it with the .to_a
    @topics_input.each do |t|
      t.allowed_user_ids = if @filter == :private_messages
        t.allowed_users.map { |u| u.id }.to_a
      else
        []
      end
    end

    @topics = @topics_input.to_a

    # Attach some data for serialization to each topic
    @topic_lookup = TopicUser.lookup_for(@current_user, @topics) if @current_user.present?

    # Create a lookup for all the user ids we need
    user_ids = []
    @topics.each do |ft|
      user_ids << ft.user_id << ft.last_post_user_id << ft.featured_user_ids << ft.allowed_user_ids
    end

    avatar_lookup = AvatarLookup.new(user_ids)

    @topics.each do |ft|
      ft.user_data = @topic_lookup[ft.id] if @topic_lookup.present?
      ft.posters = ft.posters_summary(avatar_lookup: avatar_lookup)
      ft.participants = ft.participants_summary(avatar_lookup: avatar_lookup, user: @current_user)
      ft.topic_list = self
    end

    @topics
  end

  def topic_ids
    return [] unless @topics_input
    @topics_input.pluck(:id)
  end

  def attributes
    {'more_topics_url' => page}
  end
end

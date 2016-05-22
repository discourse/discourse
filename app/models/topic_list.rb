require_dependency 'avatar_lookup'

class TopicList
  include ActiveModel::Serialization

  cattr_accessor :preloaded_custom_fields
  self.preloaded_custom_fields = Set.new

  attr_accessor :more_topics_url,
                :prev_topics_url,
                :draft,
                :draft_key,
                :draft_sequence,
                :filter,
                :for_period,
                :per_page

  def initialize(filter, current_user, topics, opts=nil)
    @filter = filter
    @current_user = current_user
    @topics_input = topics
    @opts = opts || {}

    preloaded_custom_fields << DiscourseTagging::TAGS_FIELD_NAME if SiteSetting.tagging_enabled
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
    @topics ||= load_topics
  end

  def load_topics
    @topics = @topics_input

    # Attach some data for serialization to each topic
    @topic_lookup = TopicUser.lookup_for(@current_user, @topics) if @current_user

    post_action_type =
      if @current_user
        if @opts[:filter].present?
          if @opts[:filter] == "bookmarked"
            PostActionType.types[:bookmark]
          elsif @opts[:filter] == "liked"
            PostActionType.types[:like]
          end
        end
      end

    # Include bookmarks if you have bookmarked topics
    if @current_user && !post_action_type
      post_action_type = PostActionType.types[:bookmark] if @topic_lookup.any?{|_,tu| tu && tu.bookmarked}
    end

    # Data for bookmarks or likes
    post_action_lookup = PostAction.lookup_for(@current_user, @topics, post_action_type) if post_action_type

    # Create a lookup for all the user ids we need
    user_ids = []
    @topics.each do |ft|
      user_ids << ft.user_id << ft.last_post_user_id << ft.featured_user_ids << ft.allowed_user_ids
    end

    avatar_lookup = AvatarLookup.new(user_ids)

    @topics.each do |ft|
      ft.user_data = @topic_lookup[ft.id] if @topic_lookup.present?

      if ft.user_data && post_action_lookup && actions = post_action_lookup[ft.id]
        ft.user_data.post_action_data = {post_action_type => actions}
      end

      ft.posters = ft.posters_summary(avatar_lookup: avatar_lookup)
      ft.participants = ft.participants_summary(avatar_lookup: avatar_lookup, user: @current_user)
      ft.topic_list = self
    end

    if preloaded_custom_fields.present?
      Topic.preload_custom_fields(@topics, preloaded_custom_fields)
    end

    @topics
  end

  def attributes
    {'more_topics_url' => page}
  end
end

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
      ft.posters = ft.posters_summary(ft.user_data, @current_user, avatar_lookup: avatar_lookup)
      ft.topic_list = self
    end

    return @topics
  end

  def filter_summary
    @filter_summary ||= get_summary
  end

  def attributes
    {'more_topics_url' => page}
  end

  def has_rank_details?

    # Only moderators can see rank details
    return false unless @current_user.try(:moderator?)

    # Only show them on 'Hot'
    return @filter == :hot
  end

  protected

  def get_summary
    s = {}
    return s unless @current_user
    split = SiteSetting.top_menu.split("|")

    split.each do |i|
      name, filter = i.split(",")

      exclude = nil
      if filter && filter[0] == "-"
        exclude = filter[1..-1]
      end

      query = TopicQuery.new(@current_user, exclude_category: exclude)
      s["unread"] = query.unread_count if name == 'unread'
      s["new"] = query.new_count if name == 'new'

      catSplit = name.split("/")
      if catSplit[0] == "category" && catSplit.length == 2 && @current_user
        query = TopicQuery.new(@current_user, only_category: catSplit[1], limit: false)
        s[name] = query.unread_count + query.new_count
      end
    end

    s
  end
end

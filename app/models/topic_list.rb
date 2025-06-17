# frozen_string_literal: true

class TopicList
  include ActiveModel::Serialization

  cattr_accessor :preloaded_custom_fields
  self.preloaded_custom_fields = Set.new

  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.cancel_preload(&blk)
    if @preload
      @preload.delete blk
      @preload = nil if @preload.length == 0
    end
  end

  def self.preload(topics, object)
    @preload.each { |preload| preload.call(topics, object) } if @preload
  end

  def self.on_preload_user_ids(&blk)
    (@preload_user_ids ||= Set.new) << blk
  end

  def self.preload_user_ids(topics, user_ids, object)
    if @preload_user_ids
      @preload_user_ids.each do |preload_user_ids|
        user_ids = preload_user_ids.call(topics, user_ids, object)
      end
    end
    user_ids
  end

  attr_accessor(
    :more_topics_url,
    :prev_topics_url,
    :filter,
    :for_period,
    :per_page,
    :current_user,
    :tags,
    :shared_drafts,
    :category,
    :publish_read_state,
  )

  def initialize(filter, current_user, topics, opts = nil)
    @filter = filter
    @current_user = current_user
    @topics_input = topics
    @opts = opts || {}

    @category = Category.find_by(id: @opts[:category_id]) if @opts[:category]

    @tags = Tag.where(id: @opts[:tag_ids]).all if @opts[:tag_ids].present?

    @publish_read_state = !!@opts[:publish_read_state]
  end

  def top_tags
    opts = @category ? { category: @category } : {}
    opts[:guardian] = Guardian.new(@current_user)
    Tag.top_tags(**opts)
  end

  def preload_key
    "topic_list"
  end

  # Lazy initialization
  def topics
    @topics ||= load_topics
  end

  def categories
    @categories ||=
      topics.map { |t| [t.category&.parent_category, t.category] }.flatten.uniq.compact
  end

  def load_topics
    @topics = @topics_input

    # Attach some data for serialization to each topic
    @topic_lookup = TopicUser.lookup_for(@current_user, @topics) if @current_user
    @dismissed_topic_users_lookup =
      DismissedTopicUser.lookup_for(@current_user, @topics) if @current_user

    post_action_type =
      if @current_user
        if @opts[:filter].present?
          PostActionType.types[:like] if @opts[:filter] == "liked"
        end
      end

    # Data for bookmarks or likes
    post_action_lookup =
      PostAction.lookup_for(@current_user, @topics, post_action_type) if post_action_type

    # Create a lookup for all the user ids we need
    user_ids = []
    group_ids = []
    @topics.each do |ft|
      user_ids << ft.user_id << ft.last_post_user_id << ft.featured_user_ids << ft.allowed_user_ids
      group_ids |= (ft.allowed_group_ids || [])
    end

    user_ids = TopicList.preload_user_ids(@topics, user_ids, self)
    user_lookup = UserLookup.new(user_ids)
    group_lookup = GroupLookup.new(group_ids)

    @topics.each do |ft|
      ft.user_data = @topic_lookup[ft.id] if @topic_lookup.present?

      if ft.regular? && category_user_lookup.present?
        ft.category_user_data = @category_user_lookup[ft.category_id]
      end

      ft.dismissed = @current_user && @dismissed_topic_users_lookup.include?(ft.id)

      if ft.user_data && post_action_lookup && actions = post_action_lookup[ft.id]
        ft.user_data.post_action_data = { post_action_type => actions }
      end

      ft.posters = ft.posters_summary(user_lookup: user_lookup)

      ft.participants = ft.participants_summary(user_lookup: user_lookup, user: @current_user)
      ft.participant_groups =
        ft.participant_groups_summary(group_lookup: group_lookup, group: @opts[:group])
      ft.topic_list = self
    end

    topic_preloader_associations = [
      :image_upload,
      { topic_thumbnails: :optimized_image },
      { category: :parent_category },
    ]

    topic_preloader_associations << :topic_localizations if SiteSetting.content_localization_enabled

    DiscoursePluginRegistry.topic_preloader_associations.each do |a|
      fields = a[:fields]
      condition = a[:condition]
      if condition.present?
        topic_preloader_associations << fields if condition.present? && condition.call
      else
        topic_preloader_associations << fields
      end
    end

    ActiveRecord::Associations::Preloader.new(
      records: @topics,
      associations: topic_preloader_associations,
    ).call

    if preloaded_custom_fields.present?
      Topic.preload_custom_fields(@topics, preloaded_custom_fields)
    end

    TopicList.preload(@topics, self)

    @topics
  end

  def attributes
    { "more_topics_url" => page }
  end

  private

  def category_user_lookup
    @category_user_lookup ||=
      begin
        if @current_user
          CategoryUser.lookup_for(@current_user, @topics.map(&:category_id).uniq)
        else
          []
        end
      end
  end
end

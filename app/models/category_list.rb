# frozen_string_literal: true

class CategoryList
  include ActiveModel::Serialization

  cattr_accessor :preloaded_topic_custom_fields
  self.preloaded_topic_custom_fields = Set.new

  attr_accessor :categories, :uncategorized

  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.cancel_preload(&blk)
    if @preload
      @preload.delete blk
      @preload = nil if @preload.length == 0
    end
  end

  def self.preload(category_list)
    @preload.each { |preload| preload.call(category_list) } if @preload
  end

  def initialize(guardian = nil, options = {})
    @guardian = guardian || Guardian.new
    @options = options

    find_relevant_topics if options[:include_topics]
    find_categories

    prune_empty
    find_user_data
    sort_unpinned
    trim_results
    demote_muted

    if preloaded_topic_custom_fields.present?
      displayable_topics = @categories.map(&:displayable_topics)
      displayable_topics.flatten!
      displayable_topics.compact!

      if displayable_topics.present?
        Topic.preload_custom_fields(displayable_topics, preloaded_topic_custom_fields)
      end
    end
  end

  def preload_key
    "categories_list"
  end

  def self.order_categories(categories)
    if SiteSetting.fixed_category_positions
      categories.order(:position, :id)
    else
      allowed_category_ids = categories.pluck(:id) << nil # `nil` is necessary to include categories without any associated topics
      categories
        .left_outer_joins(:featured_topics)
        .where(topics: { category_id: allowed_category_ids })
        .group("categories.id")
        .order("max(topics.bumped_at) DESC NULLS LAST")
        .order("categories.id ASC")
    end
  end

  private

  def find_relevant_topics
    @topics_by_id = {}
    @topics_by_category_id = {}

    category_featured_topics = CategoryFeaturedTopic.select(%i[category_id topic_id]).order(:rank)

    @all_topics =
      Topic.where(id: category_featured_topics.map(&:topic_id)).includes(
        :shared_draft,
        :category,
        { topic_thumbnails: %i[optimized_image upload] },
      )

    @all_topics = @all_topics.joins(:tags).where(tags: { name: @options[:tag] }) if @options[
      :tag
    ].present?

    if @guardian.authenticated?
      @all_topics =
        @all_topics.joins(
          "LEFT JOIN topic_users tu ON topics.id = tu.topic_id AND tu.user_id = #{@guardian.user.id.to_i}",
        ).where(
          "COALESCE(tu.notification_level,1) > :muted",
          muted: TopicUser.notification_levels[:muted],
        )
    end

    @all_topics = TopicQuery.remove_muted_tags(@all_topics, @guardian.user).includes(:last_poster)
    @all_topics.each do |t|
      # hint for the serializer
      t.include_last_poster = true
      t.dismissed = dismissed_topic?(t)
      @topics_by_id[t.id] = t
    end

    category_featured_topics.each do |cft|
      @topics_by_category_id[cft.category_id] ||= []
      @topics_by_category_id[cft.category_id] << cft.topic_id
    end
  end

  def dismissed_topic?(topic)
    if @guardian.current_user
      @dismissed_topic_users_lookup ||=
        DismissedTopicUser.lookup_for(@guardian.current_user, @all_topics)
      @dismissed_topic_users_lookup.include?(topic.id)
    else
      false
    end
  end

  def find_categories
    @categories =
      Category.includes(
        :uploaded_background,
        :uploaded_logo,
        :uploaded_logo_dark,
        :topic_only_relative_url,
        subcategories: [:topic_only_relative_url],
      )

    CategoryList.preload(self)

    @categories = @categories.secured(@guardian)

    @categories =
      @categories.where(
        "categories.parent_category_id = ?",
        @options[:parent_category_id].to_i,
      ) if @options[:parent_category_id].present?

    @categories = self.class.order_categories(@categories)

    @categories = @categories.to_a

    include_subcategories = @options[:include_subcategories] == true

    notification_levels = CategoryUser.notification_levels_for(@guardian.user)
    default_notification_level = CategoryUser.default_notification_level

    if @options[:parent_category_id].blank?
      subcategory_ids = {}
      subcategory_list = {}
      to_delete = Set.new
      @categories.each do |c|
        if c.parent_category_id.present?
          subcategory_ids[c.parent_category_id] ||= []
          subcategory_ids[c.parent_category_id] << c.id
          if include_subcategories
            subcategory_list[c.parent_category_id] ||= []
            subcategory_list[c.parent_category_id] << c
          end
          to_delete << c
        end
      end
      @categories.each do |c|
        c.subcategory_ids = subcategory_ids[c.id] || []
        c.subcategory_list = subcategory_list[c.id] || [] if include_subcategories
      end
      @categories.delete_if { |c| to_delete.include?(c) }
    end

    allowed_topic_create = Set.new(Category.topic_create_allowed(@guardian).pluck(:id))

    categories_with_descendants.each do |category|
      category.notification_level = notification_levels[category.id] || default_notification_level
      category.permission = CategoryGroup.permission_types[:full] if allowed_topic_create.include?(
        category.id,
      )
      category.has_children = category.subcategories.present?
    end

    if @topics_by_category_id
      categories_with_descendants.each do |c|
        topics_in_cat = @topics_by_category_id[c.id]
        if topics_in_cat.present?
          c.displayable_topics = []
          topics_in_cat.each do |topic_id|
            topic = @topics_by_id[topic_id]
            if topic.present? && @guardian.can_see?(topic)
              # topic.category is very slow under rails 4.2
              topic.association(:category).target = c
              c.displayable_topics << topic
            end
          end
        end
      end
    end
  end

  def prune_empty
    return if SiteSetting.allow_uncategorized_topics
    @categories.delete_if { |c| c.uncategorized? }
  end

  # Attach some data for serialization to each topic
  def find_user_data
    if @guardian.current_user && @all_topics.present?
      topic_lookup = TopicUser.lookup_for(@guardian.current_user, @all_topics)
      @all_topics.each { |ft| ft.user_data = topic_lookup[ft.id] }
    end
  end

  # Put unpinned topics at the end of the list
  def sort_unpinned
    if @guardian.current_user && @all_topics.present?
      categories_with_descendants.each do |c|
        next if c.displayable_topics.blank? || c.displayable_topics.size <= c.num_featured_topics
        unpinned = []
        c.displayable_topics.each do |t|
          unpinned << t if t.pinned_at && PinnedCheck.unpinned?(t, t.user_data)
        end
        c.displayable_topics = (c.displayable_topics - unpinned) + unpinned unless unpinned.empty?
      end
    end
  end

  def demote_muted
    muted_categories = @categories.select { |category| category.notification_level == 0 }
    @categories = @categories.reject { |category| category.notification_level == 0 }
    @categories.concat muted_categories
  end

  def trim_results
    categories_with_descendants.each do |c|
      next if c.displayable_topics.blank?
      c.displayable_topics = c.displayable_topics[0, c.num_featured_topics]
    end
  end

  def categories_with_descendants(categories = @categories)
    return @categories_with_children if @categories_with_children && (categories == @categories)
    return nil if categories.nil?

    result = categories.flat_map { |c| [c, *categories_with_descendants(c.subcategory_list)] }

    @categories_with_children = result if categories == @categories

    result
  end
end

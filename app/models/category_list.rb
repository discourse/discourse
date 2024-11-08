# frozen_string_literal: true

class CategoryList
  CATEGORIES_PER_PAGE = 20
  SUBCATEGORIES_PER_CATEGORY = 5

  # Maximum number of categories before the optimized category page style is enforced
  MAX_UNOPTIMIZED_CATEGORIES = 1000

  include ActiveModel::Serialization

  cattr_accessor :preloaded_topic_custom_fields
  self.preloaded_topic_custom_fields = Set.new

  attr_accessor :categories, :uncategorized

  def self.register_included_association(association)
    @included_associations ||= []
    @included_associations << association if !@included_associations.include?(association)
  end

  def self.included_associations
    [
      :uploaded_background,
      :uploaded_background_dark,
      :uploaded_logo,
      :uploaded_logo_dark,
      :topic_only_relative_url,
      subcategories: [:topic_only_relative_url],
    ].concat(@included_associations || [])
  end

  def initialize(guardian = nil, options = {})
    @guardian = guardian || Guardian.new
    @options = options

    find_categories
    find_relevant_topics if options[:include_topics]

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
      categories
        .left_outer_joins(:featured_topics)
        .where("topics.category_id IS NULL OR topics.category_id IN (?)", categories.select(:id))
        .group("categories.id")
        .order("max(topics.bumped_at) DESC NULLS LAST")
        .order("categories.id ASC")
    end
  end

  private

  def relevant_topics_query
    @all_topics =
      Topic
        .secured(@guardian)
        .joins(
          "INNER JOIN category_featured_topics ON topics.id = category_featured_topics.topic_id",
        )
        .where("category_featured_topics.category_id IN (?)", categories_with_descendants.map(&:id))
        .select(
          "topics.*, category_featured_topics.category_id AS category_featured_topic_category_id",
        )
        .includes(:shared_draft, :category, { topic_thumbnails: %i[optimized_image upload] })
        .order("category_featured_topics.rank")

    @all_topics = @all_topics.joins(:tags).where(tags: { name: @options[:tag] }) if @options[
      :tag
    ].present?

    if @guardian.authenticated?
      @all_topics =
        @all_topics
          .joins(
            "LEFT JOIN topic_users tu ON topics.id = tu.topic_id AND tu.user_id = #{@guardian.user.id.to_i}",
          )
          .joins(
            "LEFT JOIN category_users ON category_users.category_id = topics.category_id AND category_users.user_id = #{@guardian.user.id}",
          )
          .where(
            "COALESCE(tu.notification_level,1) > :muted",
            muted: TopicUser.notification_levels[:muted],
          )
    end

    @all_topics = TopicQuery.remove_muted_tags(@all_topics, @guardian.user).includes(:last_poster)
  end

  def find_relevant_topics
    featured_topics_by_category_id = Hash.new { |h, k| h[k] = [] }

    relevant_topics_query.each do |t|
      # hint for the serializer
      t.include_last_poster = true
      t.dismissed = dismissed_topic?(t)
      featured_topics_by_category_id[t.category_featured_topic_category_id] << t
    end

    categories_with_descendants.each do |category|
      category.displayable_topics = featured_topics_by_category_id[category.id]
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
    query = Category.includes(CategoryList.included_associations).secured(@guardian)
    query = self.class.order_categories(query)

    if @options[:parent_category_id].present? || @guardian.can_lazy_load_categories?
      query = query.where(parent_category_id: @options[:parent_category_id])
    end

    style =
      if Category.secured(@guardian).count > MAX_UNOPTIMIZED_CATEGORIES
        "categories_only_optimized"
      else
        SiteSetting.desktop_category_page_style
      end
    page = [1, @options[:page].to_i].max
    if style == "categories_only_optimized" || @guardian.can_lazy_load_categories?
      query = query.limit(CATEGORIES_PER_PAGE).offset((page - 1) * CATEGORIES_PER_PAGE)
    elsif page > 1
      # Pagination is supported only when lazy load is enabled. If it is not,
      # everything is returned on page 1.
      query = query.none
    end

    query =
      DiscoursePluginRegistry.apply_modifier(:category_list_find_categories_query, query, self)

    @categories = query.to_a

    if @guardian.can_lazy_load_categories? && @options[:parent_category_id].blank?
      categories_with_rownum =
        Category
          .secured(@guardian)
          .select(:id, "ROW_NUMBER() OVER (PARTITION BY parent_category_id) rownum")
          .where(parent_category_id: @categories.map { |c| c.id })

      @categories +=
        Category.includes(CategoryList.included_associations).where(
          "id IN (WITH cte AS (#{categories_with_rownum.to_sql}) SELECT id FROM cte WHERE rownum <= ?)",
          SUBCATEGORIES_PER_CATEGORY,
        )
    end

    if Site.preloaded_category_custom_fields.any?
      Category.preload_custom_fields(@categories, Site.preloaded_category_custom_fields)
    end

    include_subcategories = @options[:include_subcategories] == true

    if @guardian.can_lazy_load_categories?
      subcategory_ids = {}
      Category
        .secured(@guardian)
        .where(parent_category_id: @categories.map(&:id))
        .pluck(:id, :parent_category_id)
        .each { |id, parent_id| (subcategory_ids[parent_id] ||= []) << id }
      @categories.each { |c| c.subcategory_ids = subcategory_ids[c.id] || [] }
    elsif @options[:parent_category_id].blank?
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

    Category.preload_user_fields!(@guardian, categories_with_descendants)
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

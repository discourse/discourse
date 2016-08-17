class CategoryList
  include ActiveModel::Serialization

  attr_accessor :categories,
                :uncategorized,
                :draft,
                :draft_key,
                :draft_sequence

  def initialize(guardian=nil, options={})
    @guardian = guardian || Guardian.new
    @options = options

    find_categories
  end

  def preload_key
    "categories_list".freeze
  end

  private

    # Find a list of all categories to associate the topics with
    def find_categories
      @categories = Category.includes(:topic_only_relative_url, subcategories: [:topic_only_relative_url]).secured(@guardian)
      @categories = @categories.where(suppress_from_homepage: false) if @options[:is_homepage]

      unless SiteSetting.allow_uncategorized_topics
        # TODO: also make sure the uncategorized is empty
        @categories = @categories.where("id <> #{SiteSetting.uncategorized_category_id}")
      end

      if SiteSetting.fixed_category_positions
        @categories = @categories.order(:position, :id)
      else
        @categories = @categories.order('COALESCE(categories.posts_week, 0) DESC')
                                 .order('COALESCE(categories.posts_month, 0) DESC')
                                 .order('COALESCE(categories.posts_year, 0) DESC')
                                 .order('id ASC')
      end

      @categories = @categories.to_a

      category_user = {}
      unless @guardian.anonymous?
        category_user = Hash[*CategoryUser.where(user: @guardian.user).pluck(:category_id, :notification_level).flatten]
      end

      allowed_topic_create = Set.new(Category.topic_create_allowed(@guardian).pluck(:id))
      @categories.each do |category|
        category.notification_level = category_user[category.id]
        category.permission = CategoryGroup.permission_types[:full] if allowed_topic_create.include?(category.id)
        category.has_children = category.subcategories.present?
      end

      subcategories = {}
      to_delete = Set.new
      @categories.each do |c|
        if c.parent_category_id.present?
          subcategories[c.parent_category_id] ||= []
          subcategories[c.parent_category_id] << c.id
          to_delete << c
        end
      end

      @categories.each { |c| c.subcategory_ids = subcategories[c.id] }

      @categories.delete_if { |c| to_delete.include?(c) }
    end
end

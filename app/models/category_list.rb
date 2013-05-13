class CategoryList
  include ActiveModel::Serialization

  attr_accessor :categories, :topic_users, :uncategorized

  def initialize(guardian)
    guardian ||= Guardian.new

    @categories = Category
                    .includes(featured_topics: [:category])
                    .includes(:featured_users)
                    .where('topics.visible' => true)
                    .secured(guardian)
                    .order('categories.topics_week desc, categories.topics_month desc, categories.topics_year desc')


    @categories = @categories.to_a

    # Support for uncategorized topics
    uncategorized_topics = Topic
                      .listable_topics
                      .where(category_id: nil)
                      .topic_list_order
                      .limit(SiteSetting.category_featured_topics)
    if uncategorized_topics.present?

      totals = Topic.exec_sql("SELECT SUM(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '1 WEEK') THEN 1 ELSE 0 END) as topics_week,
                                      SUM(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '1 MONTH') THEN 1 ELSE 0 END) as topics_month,
                                      SUM(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '1 YEAR') THEN 1 ELSE 0 END) as topics_year,
                                      COUNT(*) AS topic_count
                               FROM topics
                               WHERE topics.visible
                                AND topics.deleted_at IS NULL
                                AND topics.category_id IS NULL
                                AND topics.archetype <> '#{Archetype.private_message}'").first


      uncategorized = Category.new({name: SiteSetting.uncategorized_name,
                                   slug: Slug.for(SiteSetting.uncategorized_name),
                                   color: SiteSetting.uncategorized_color,
                                   text_color: SiteSetting.uncategorized_text_color,
                                   featured_topics: uncategorized_topics}.merge(totals))

      # Find the appropriate place to insert it:
      insert_at = nil
      @categories.each_with_index do |c, idx|
        if totals['topics_week'].to_i > (c.topics_week || 0)
          insert_at = idx
          break
        end
      end

      @categories.insert(insert_at || @categories.size, uncategorized)
    end

    unless guardian.can_create?(Category)
      # Remove categories with no featured topics unless we have the ability to edit one
      @categories.delete_if { |c| c.featured_topics.blank? }
    else
      # Show all categories to people who have the ability to edit and delete categories
      if @categories.size > 0
        @categories.insert(@categories.size, *Category.where('id not in (?)', @categories.map(&:id).compact).to_a)
      else
        @categories = Category.all.to_a
      end
    end

    # Get forum topic user records if appropriate
    if guardian.current_user
      topics = []
      @categories.each { |c| topics << c.featured_topics }
      topics << @uncategorized

      topics.flatten! if topics.present?
      topics.compact! if topics.present?

      topic_lookup = TopicUser.lookup_for(guardian.current_user, topics)

      # Attach some data for serialization to each topic
      topics.each { |ft| ft.user_data = topic_lookup[ft.id] }
    end
  end
end

class CategoryList
  include ActiveModel::Serialization

  attr_accessor :categories,
                :topic_users,
                :uncategorized,
                :draft,
                :draft_key,
                :draft_sequence

  def initialize(guardian=nil, options = {})
    @guardian = guardian || Guardian.new
    @options = options

    find_relevant_topics unless latest_post_only?
    find_categories

    prune_empty
    add_uncategorized
    find_user_data
  end

  private

    def latest_post_only?
      @options[:latest_post_only]
    end

    # Retrieve a list of all the topics we'll need
    def find_relevant_topics
      @topics_by_category_id = {}
      category_featured_topics = CategoryFeaturedTopic.select([:category_id, :topic_id]).order(:rank)
      @topics_by_id = {}

      @all_topics = Topic.where(id: category_featured_topics.map(&:topic_id))
      @all_topics.each do |t|
        @topics_by_id[t.id] = t
      end

      category_featured_topics.each do |cft|
        @topics_by_category_id[cft.category_id] ||= []
        @topics_by_category_id[cft.category_id] << cft.topic_id
      end
    end

    # Find a list of all categories to associate the topics with
    def find_categories
      @categories = Category
                      .includes(:featured_users)
                      .secured(@guardian)

      if latest_post_only?
        @categories = @categories
                        .includes(:latest_post => {:topic => :last_poster} )
                        .order('position ASC')
      else
        @categories = @categories
                        .order('COALESCE(categories.topics_week, 0) DESC')
                        .order('COALESCE(categories.topics_month, 0) DESC')
                        .order('COALESCE(categories.topics_year, 0) DESC')
      end

      @categories = @categories.to_a

      if latest_post_only?
        @all_topics = []
        @categories.each do |c|
          if c.latest_post && c.latest_post.topic
            c.displayable_topics = [c.latest_post.topic]
            topic = c.latest_post.topic
            topic.include_last_poster = true # hint for serialization
            @all_topics << topic
          end
        end
      end

      if @topics_by_category_id
        @categories.each do |c|
          topics_in_cat = @topics_by_category_id[c.id]
          if topics_in_cat.present?
            c.displayable_topics = []
            topics_in_cat.each do |topic_id|
              topic = @topics_by_id[topic_id]
              if topic.present?
                topic.category = c
                c.displayable_topics << topic
              end
            end
          end
        end
      end
    end

    # Add the uncategorized "magic" category
    # TODO: remove this entire hack, not needed
    def add_uncategorized
      # Support for uncategorized topics
      uncategorized_topics = Topic
                        .listable_topics
                        .visible
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

        unless latest_post_only?
          @categories.each_with_index do |c, idx|
            if (uncategorized.topics_week || 0) > (c.topics_week || 0)
              insert_at = idx
              break
            end
          end
        end

        @categories.insert(insert_at || @categories.size, uncategorized)
      end

      if uncategorized.present?
        @all_topics ||= []
        uncategorized.displayable_topics = uncategorized_topics
        @all_topics << uncategorized_topics
        @all_topics.flatten!
      end
    end

    # Remove any empty topics unless we can create them (so we can see the controls)
    def prune_empty
      unless @guardian.can_create?(Category)
        # Remove categories with no featured topics unless we have the ability to edit one
        @categories.delete_if { |c| c.displayable_topics.blank? && c.description.nil? }
      end
    end

    # Get forum topic user records if appropriate
    def find_user_data
      if @guardian.current_user && @all_topics.present?
        topic_lookup = TopicUser.lookup_for(@guardian.current_user, @all_topics)

        # Attach some data for serialization to each topic
        @all_topics.each { |ft| ft.user_data = topic_lookup[ft.id] }
      end
    end
end

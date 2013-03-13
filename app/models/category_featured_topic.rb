class CategoryFeaturedTopic < ActiveRecord::Base
  belongs_to :category
  belongs_to :topic

  # Populates the category featured topics
  def self.feature_topics
    transaction do
      Category.all.each do |c|
        feature_topics_for(c)
        CategoryFeaturedUser.feature_users_in(c)
      end
    end
  end

  def self.feature_topics_for(c)
    return if c.blank?

    CategoryFeaturedTopic.transaction do
      exec_sql "DELETE FROM category_featured_topics WHERE category_id = :category_id", category_id: c.id
      exec_sql "INSERT INTO category_featured_topics (category_id, topic_id, created_at, updated_at)
                SELECT :category_id,
                       ft.id,
                       CURRENT_TIMESTAMP,
                       CURRENT_TIMESTAMP
                FROM topics AS ft
                WHERE ft.category_id = :category_id
                  AND ft.visible
                  AND ft.deleted_at IS NULL
                  AND ft.archetype <> '#{Archetype.private_message}'
                ORDER BY ft.bumped_at DESC
                LIMIT :featured_limit",
                category_id: c.id,
                featured_limit: SiteSetting.category_featured_topics
    end
  end

end

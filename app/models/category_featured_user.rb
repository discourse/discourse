class CategoryFeaturedUser < ActiveRecord::Base
  belongs_to :category
  belongs_to :user

  def self.max_featured_users
    5
  end

  def self.feature_users_in(category)
    # Figure out major posters in the category
    user_counts = exec_sql "
      SELECT p.user_id,
             COUNT(*) AS category_posts
      FROM posts AS p
      INNER JOIN topics AS ft ON ft.id = p.topic_id
      WHERE ft.category_id = :category_id
      GROUP BY p.user_id
      ORDER BY category_posts DESC
      LIMIT :max_featured_users
    ", category_id: category.id, max_featured_users: max_featured_users

    transaction do
      CategoryFeaturedUser.delete_all category_id: category.id
      user_counts.each do |uc|
        create(category_id: category.id, user_id: uc['user_id'])
      end
    end

  end

end

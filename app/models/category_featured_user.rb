class CategoryFeaturedUser < ActiveRecord::Base
  belongs_to :category
  belongs_to :user

  def self.max_featured_users
    5
  end

  def self.feature_users_in(category_or_category_id)
    category_id =
      if category_or_category_id.is_a?(Fixnum)
        category_or_category_id
      else
        category_or_category_id.id
      end

    # Figure out most recent posters in the category
    most_recent_user_ids = exec_sql "
      SELECT x.user_id
      FROM (
        SELECT DISTINCT ON (p.user_id) p.user_id AS user_id,
               p.created_at AS created_at
        FROM posts AS p
        INNER JOIN topics AS ft ON ft.id = p.topic_id
        WHERE ft.category_id = :category_id
        AND p.user_id IS NOT NULL
        ORDER BY p.user_id, p.created_at DESC
      ) AS x
      ORDER BY x.created_at DESC
      LIMIT :max_featured_users;
    ", category_id: category_id, max_featured_users: max_featured_users

    user_ids = most_recent_user_ids.map{|uc| uc['user_id'].to_i}
    current = CategoryFeaturedUser.where(category_id: category_id).order(:id).pluck(:user_id)

    return if current == user_ids

    transaction do
      CategoryFeaturedUser.delete_all category_id: category_id
      user_ids.each do |user_id|
        create(category_id: category_id, user_id: user_id)
      end
    end

  end

end

# == Schema Information
#
# Table name: category_featured_users
#
#  id          :integer          not null, primary key
#  category_id :integer
#  user_id     :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_category_featured_users_on_category_id_and_user_id  (category_id,user_id) UNIQUE
#

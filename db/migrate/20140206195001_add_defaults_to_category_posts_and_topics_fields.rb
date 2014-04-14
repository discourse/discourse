class AddDefaultsToCategoryPostsAndTopicsFields < ActiveRecord::Migration
  def change
    change_column_default :categories, :posts_week,   0
    change_column_default :categories, :posts_month,  0
    change_column_default :categories, :posts_year,   0

    change_column_default :categories, :topics_week,  0
    change_column_default :categories, :topics_month, 0
    change_column_default :categories, :topics_year,  0
  end
end

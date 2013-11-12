class AddDescriptionToCategories < ActiveRecord::Migration
  def up
    add_column :categories, :description, :text, null: true

    # While we're at it, remove unused columns
    remove_column :categories, :top1_topic_id
    remove_column :categories, :top2_topic_id
    remove_column :categories, :top1_user_id
    remove_column :categories, :top2_user_id

    # Migrate excerpts over
    Category.order('id').each do |c|
      post = c.topic.posts.order(:post_number).first
      PostRevisor.new(post).send(:update_category_description)
    end

  end

  def down
    remove_column :categories, :description
  end

end

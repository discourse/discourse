class AddDescriptionToCategories < ActiveRecord::Migration
  def up
    add_column :categories, :description, :text, null: true

    # While we're at it, remove unused columns
    remove_column :categories, :top1_topic_id
    remove_column :categories, :top2_topic_id
    remove_column :categories, :top1_user_id
    remove_column :categories, :top2_user_id

    # Migrate excerpts over
    Category.all.each do |c| 
      excerpt = c.excerpt
      unless excerpt == I18n.t("category.replace_paragraph")
        c.update_column(:description, c.excerpt)
      end
    end

  end

  def down
    remove_column :categories, :description
  end

end

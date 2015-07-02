class AddTopicTemplateToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :topic_template, :text, null: true
  end
end

class AddTopicTemplateToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :topic_template, :text, null: true
  end
end

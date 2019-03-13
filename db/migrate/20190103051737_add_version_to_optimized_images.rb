class AddVersionToOptimizedImages < ActiveRecord::Migration[5.2]
  def change
    add_column :optimized_images, :version, :integer
  end
end

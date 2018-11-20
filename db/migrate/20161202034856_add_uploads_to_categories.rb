class AddUploadsToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :uploaded_logo_id, :integer, index: true
    add_column :categories, :uploaded_background_id, :integer, index: true

    transaction do
      Category.find_each do |category|
        logo_upload = Upload.find_by(url: category.logo_url)
        background_upload = Upload.find_by(url: category.background_url)

        category.update_columns(
          uploaded_logo_id: logo_upload&.id,
          uploaded_background_id: background_upload&.id
        )
      end
    end
  end
end

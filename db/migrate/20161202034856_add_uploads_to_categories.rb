class AddUploadsToCategories < ActiveRecord::Migration
  def up
    add_column :categories, :uploaded_logo_id, :integer, index: true
    add_column :categories, :uploaded_background_id, :integer, index: true

    transaction do
      Category.find_each do |category|
        logo_upload = Upload.find_by(url: category.logo_url)
        category.uploaded_logo_id = logo_upload.id if logo_upload

        background_upload = Upload.find_by(url: category.background_url)
        category.uploaded_background_id = background_upload.id if background_upload

        category.save!
      end
    end
  end
end

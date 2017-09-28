class AddUrlToOptimizedImages < ActiveRecord::Migration[4.2]
  def up
    # add a nullable url column
    add_column :optimized_images, :url, :string
    # compute the url for existing images
    execute "UPDATE optimized_images
             SET url = substring(u.url from '^\/uploads\/[^/]+\/')
                    || '_optimized/'
                    || substring(oi.sha1 for 3) || '/'
                    || substring(oi.sha1 from 4 for 3) || '/'
                    || substring(oi.sha1 from 7 for 11) || oi.extension
            FROM optimized_images oi
            JOIN uploads u ON u.id = oi.upload_id
            WHERE optimized_images.id = oi.id;"
    # change the column to be non nullable
    change_column :optimized_images, :url, :string, null: false
  end

  def down
    remove_column :optimized_images, :url
  end
end

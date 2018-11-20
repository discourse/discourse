class FixOptimizedImagesUrls < ActiveRecord::Migration[4.2]
  def up
    # `AddUrlToOptimizedImages` was wrongly computing the URLs. This fixes it!
    execute "UPDATE optimized_images
             SET url = substring(oi.url from '^\\/uploads\\/[^/]+\\/_optimized\\/[0-9a-f]{3}\\/[0-9a-f]{3}\\/[0-9a-f]{11}')
                    || '_'
                    || oi.width
                    || 'x'
                    || oi.height
                    || substring(oi.url from '\\.\\w{3,4}$')
             FROM optimized_images oi
             WHERE optimized_images.id = oi.id
               AND oi.url ~ '^\\/uploads\\/[^/]+\\/_optimized\\/[0-9a-f]{3}\\/[0-9a-f]{3}\\/[0-9a-f]{11}\\.';"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

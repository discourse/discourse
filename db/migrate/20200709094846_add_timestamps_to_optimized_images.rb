# frozen_string_literal: true
class AddTimestampsToOptimizedImages < ActiveRecord::Migration[6.0]
  def change
    add_column :optimized_images, :created_at, :datetime, null: true
    add_column :optimized_images, :updated_at, :datetime, null: true

    # Start by stealing created/updated at from the uploads table
    # Not perfect, but a good approximation
    execute <<~SQL
      UPDATE optimized_images
      SET created_at = uploads.created_at,
          updated_at = uploads.created_at
      FROM uploads
      WHERE uploads.id = optimized_images.upload_id
    SQL

    # Integrity is not enforced, we might have optimized images
    # with no uploads
    execute <<~SQL
      UPDATE optimized_images
      SET created_at = NOW(),
          updated_at = NOW()
      WHERE created_at IS NULL
    SQL

    execute <<~SQL
      ALTER TABLE optimized_images ALTER COLUMN created_at SET NOT NULL;
    SQL

    execute <<~SQL
      ALTER TABLE optimized_images ALTER COLUMN updated_at SET NOT NULL;
    SQL
  end
end

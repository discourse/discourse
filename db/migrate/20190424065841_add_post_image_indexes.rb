# frozen_string_literal: true

class AddPostImageIndexes < ActiveRecord::Migration[5.2]
  def change

    %w{
      large_images
      broken_images
      downloaded_images
    }.each do |field|

      execute <<~SQL
        DELETE FROM post_custom_fields f
        WHERE name = '#{field}' AND id > (
          SELECT MIN(f2.id) FROM post_custom_fields f2
            WHERE f2.post_id = f.post_id AND f2.name = f.name
        )
      SQL

      add_index :post_custom_fields, [:post_id],
        name: "post_custom_field_#{field}_idx",
        unique: true,
        where: "name = '#{field}'"
    end
  end
end

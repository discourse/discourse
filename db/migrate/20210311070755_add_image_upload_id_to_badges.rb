# frozen_string_literal: true

class AddImageUploadIdToBadges < ActiveRecord::Migration[6.0]
  def change
    add_column :badges, :image_upload_id, :integer
    reversible do |dir|
      dir.up do
        DB.exec <<~SQL
          UPDATE badges b1
          SET image_upload_id = u.id
          FROM badges b2
          INNER JOIN uploads u
          ON b2.image ~ CONCAT('/', u.sha1, '\\.\\w')
          WHERE b1.id = b2.id
        SQL
      end
    end
  end
end

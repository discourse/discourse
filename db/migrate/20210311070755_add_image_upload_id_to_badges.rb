# frozen_string_literal: true

class AddImageUploadIdToBadges < ActiveRecord::Migration[6.0]
  def change
    add_column :badges, :image_upload_id, :integer
    reversible { |dir| dir.up { DB.exec <<~SQL } }
          UPDATE badges b1
          SET image_upload_id = u.id
          FROM (
            SELECT id, (regexp_matches(b.image, '[a-f0-9]{40}'))[1] as sha1
            FROM badges b
            WHERE
              b.image IS NOT NULL AND
              b.image ~ '[a-f0-9]{40}'
          ) b2
          JOIN uploads u ON u.sha1 = b2.sha1
          WHERE
            b1.id = b2.id
        SQL
  end
end

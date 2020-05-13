# frozen_string_literal: true

class AddMoreFlairColumnsToGroup < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :flair_icon, :string
    add_reference :groups, :flair_image, foreign_key: { to_table: :uploads }

    DB.exec(
      <<~SQL
        UPDATE groups SET flair_icon = REPLACE(REPLACE(flair_url, 'fas fa-', ''), ' fa-', '-')
        WHERE flair_url LIKE 'fa%'
      SQL
    )

    DB.exec(
      <<~SQL
        UPDATE groups g1
        SET flair_image_id = u.id
        FROM groups g2
        INNER JOIN uploads u ON g2.flair_url ~ CONCAT('\/', u.sha1, '[\.\w]*')
        WHERE g1.id = g2.id
      SQL
    )

  end
end

# frozen_string_literal: true

class AddMoreFlairColumnsToGroup < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :flair_icon, :string
    add_reference :groups, :flair_image, foreign_key: { to_table: :uploads }

    DB.exec(
      <<~SQL
        UPDATE groups SET flair_icon = flair_url
        WHERE flair_url LIKE 'fa%'
      SQL
    )

    DB.exec(
      <<~SQL
        UPDATE groups g1
        SET flair_image_id = u.id
        FROM groups g2
        INNER JOIN uploads u ON u.url = g2.flair_url
          OR g2.flair_url ~ CONCAT('\/(original|optimized|short-url)\/(\dX[\/\.\w]*\/)?', u.sha1, '[\.\w]*')
        WHERE g1.id = g2.id AND g1.flair_url IS NOT NULL AND g1.flair_url NOT LIKE 'fa%'
      SQL
    )

    DB.exec(
      <<~SQL
        UPDATE groups SET flair_url = NULL
        WHERE flair_icon IS NOT NULL OR flair_image_id IS NOT NULL
      SQL
    )
  end
end

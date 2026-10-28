# frozen_string_literal: true

class RetainBlogReviewUploads < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 100
  BASE62_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def up
    return unless Migration::Helpers.existing_site?

    last_id = 0
    loop do
      reviews = DB.query(<<~SQL, last_id: last_id, batch_size: BATCH_SIZE)
        SELECT id, cooked
        FROM discourse_blog_reviews
        WHERE id > :last_id AND revoked_at IS NULL AND expires_at > CURRENT_TIMESTAMP
        ORDER BY id
        LIMIT :batch_size
      SQL
      break if reviews.empty?

      reviews.each do |review|
        sha1s = review.cooked.scan(%r{/([0-9a-f]{40})(?:[_./"?#]|$)}).flatten
        review
          .cooked
          .scan(%r{/uploads/short-url/([a-zA-Z0-9]+)})
          .flatten
          .each do |encoded|
            next if encoded.length > 27
            value =
              encoded
                .each_char
                .reduce(0) { |number, character| number * 62 + BASE62_ALPHABET.index(character) }
            hex = value.to_s(16)
            sha1s << hex.rjust(40, "0") if hex.length <= 40
          end
        next if sha1s.empty?

        DB.exec(<<~SQL, review_id: review.id, sha1s: sha1s.uniq)
          INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
          SELECT upload_id, 'DiscourseBlog::Review', :review_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          FROM (
            SELECT id AS upload_id FROM uploads WHERE sha1 IN (:sha1s)
            UNION
            SELECT optimized_images.upload_id
            FROM optimized_images
            JOIN uploads ON uploads.id = optimized_images.upload_id
            WHERE optimized_images.sha1 IN (:sha1s)
          ) snapshot_uploads
          WHERE EXISTS (
            SELECT 1 FROM discourse_blog_reviews
            WHERE id = :review_id AND revoked_at IS NULL AND expires_at > CURRENT_TIMESTAMP
          )
          ON CONFLICT (upload_id, target_type, target_id) DO NOTHING
        SQL
      end
      last_id = reviews.last.id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

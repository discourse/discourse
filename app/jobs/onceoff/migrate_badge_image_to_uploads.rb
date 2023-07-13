# frozen_string_literal: true
require "uri"

module Jobs
  class MigrateBadgeImageToUploads < ::Jobs::Onceoff
    def execute_onceoff(args)
      column_exists = DB.exec(<<~SQL) == 1
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE
          table_schema = 'public' AND
          table_name = 'badges' AND
          column_name = 'image_upload_id'
      SQL
      return unless column_exists

      Badge
        .where.not(image: nil)
        .select(:id, :image_upload_id, :image)
        .each do |badge|
          if badge.image_upload.present?
            DB.exec("UPDATE badges SET image = NULL WHERE id = ?", badge.id)
            next
          end

          image_url = badge[:image]
          next if image_url.blank? || image_url !~ URI.regexp

          count = 0
          file = nil
          sleep_interval = 5

          loop do
            url = UrlHelper.absolute_without_cdn(image_url)

            begin
              file =
                FileHelper.download(
                  url,
                  max_file_size: [SiteSetting.max_image_size_kb.kilobytes, 20.megabytes].max,
                  tmp_file_name: "tmp_badge_image_upload",
                  skip_rate_limit: true,
                  follow_redirect: true,
                )
            rescue OpenURI::HTTPError,
                   OpenSSL::SSL::SSLError,
                   Net::OpenTimeout,
                   Net::ReadTimeout,
                   Errno::ECONNREFUSED,
                   EOFError,
                   SocketError,
                   Discourse::InvalidParameters => e
              logger.error(
                "Error encountered when trying to download from URL '#{image_url}' " +
                  "for badge '#{badge[:id]}'.\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}",
              )
            end

            count += 1
            break if file

            logger.warn(
              "Failed to download image from #{url} for badge '#{badge[:id]}'. Retrying (#{count}/3)...",
            )
            break if count >= 3
            sleep(count * sleep_interval)
          end

          next if file.blank?

          upload =
            UploadCreator.new(
              file,
              "image_for_badge_#{badge[:id]}",
              origin: UrlHelper.absolute(image_url),
            ).create_for(Discourse.system_user.id)

          if upload.errors.count > 0 || upload&.id.blank?
            logger.error(
              "Failed to create an upload for the image of badge '#{badge[:id]}'. Error: #{upload.errors.full_messages}",
            )
          else
            DB.exec(
              "UPDATE badges SET image = NULL, image_upload_id = ? WHERE id = ?",
              upload.id,
              badge[:id],
            )
          end
        end
    end

    private

    def logger
      Rails.logger
    end
  end
end

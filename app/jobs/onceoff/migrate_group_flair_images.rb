# frozen_string_literal: true
require 'uri'

module Jobs
  class MigrateGroupFlairImages < ::Jobs::Onceoff
    def execute_onceoff(args)
      column_exists = DB.exec(<<~SQL) == 1
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE
          table_schema = 'public' AND
          table_name = 'groups' AND
          column_name = 'flair_url'
      SQL
      return unless column_exists

      groups = Group.where.not(flair_url: nil).select(:id, :flair_url, :flair_upload_id, :name)
      groups.each do |group|
        if group.flair_upload.present?
          DB.exec("UPDATE groups SET flair_url = NULL WHERE id = #{group.id}")
          next
        end

        old_url = group[:flair_url]
        next if old_url.blank? || old_url !~ URI::regexp

        group_name = group.name

        count = 0
        file = nil
        sleep_interval = 5

        loop do
          url = UrlHelper.absolute_without_cdn(old_url)

          begin
            file = FileHelper.download(
              url,
              max_file_size: [
                SiteSetting.max_image_size_kb.kilobytes,
                20.megabytes
              ].max,
              tmp_file_name: 'tmp_group_flair_upload',
              skip_rate_limit: true,
              follow_redirect: true
            )
          rescue OpenURI::HTTPError,
                 OpenSSL::SSL::SSLError,
                 Net::OpenTimeout,
                 Net::ReadTimeout,
                 Errno::ECONNREFUSED,
                 EOFError,
                 SocketError,
                 Discourse::InvalidParameters => e

            logger.warn(
              "Error encountered when trying to download from URL '#{old_url}' " +
              "for group '#{group_name}'.\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
            )
          end

          count += 1
          break if file || (file.blank? && count >= 3)

          logger.info(
            "Failed to download upload from #{url} for group '#{group_name}'. Retrying..."
          )

          sleep(count * sleep_interval)
        end

        next if file.blank?

        upload = UploadCreator.new(
          file,
          "group_#{group_name}",
          origin: UrlHelper.absolute(old_url)
        ).create_for(Discourse.system_user.id)

        if upload.errors.count > 0
          logger.warn("Failed to create upload for '#{group_name}' group_flair: #{upload.errors.full_messages}")
        else
          DB.exec("UPDATE groups SET flair_url = NULL, flair_upload_id = #{upload.id} WHERE id = #{group.id}") if upload&.id.present?
        end
      end
    end

    private

    def logger
      Rails.logger
    end
  end
end

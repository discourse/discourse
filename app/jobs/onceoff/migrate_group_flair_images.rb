# frozen_string_literal: true
require 'uri'

module Jobs
  class MigrateGroupFlairImages < ::Jobs::Onceoff
    def execute_onceoff(args)
      return if Group.column_names.exclude?("flair_url")

      Group.where.not(flair_url: nil).each do |group|
        if group.flair_upload.present?
          g.update_column(:flair_url, nil)
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

        group.update_columns(flair_upload_id: upload.id, flair_url: nil) if upload.present?
      end
    end

    private

    def logger
      Rails.logger
    end
  end
end

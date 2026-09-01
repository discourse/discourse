# frozen_string_literal: true

module Jobs
  module Chat
    class PullHotlinkedImages < ::Jobs::Base
      sidekiq_options queue: "low"

      def execute(args)
        @chat_message_id = args[:chat_message_id]
        raise Discourse::InvalidParameters.new(:chat_message_id) if @chat_message_id.blank?
        return if !SiteSetting.chat_allow_uploads?

        if Jobs.run_immediately?
          pull
        else
          DistributedMutex.synchronize(
            "chat_pull_hotlinked_images_#{@chat_message_id}",
            validity: 2.minutes,
          ) { pull }
        end
      end

      private

      def pull
        chat_message = ::Chat::Message.find_by(id: @chat_message_id)
        return if chat_message.nil? || chat_message.cooked.blank?
        # Don't re-cook system/webhook messages whose cooked is hand-written.
        return if chat_message.message.blank?

        hotlinked_map = chat_message.hotlinked_media.preload(:upload).index_by(&:url)
        needs_recook = false

        HotlinkedMedia
          .extract_candidates(chat_message.cooked)
          .each do |node|
            # chat only localizes imgs; downloading other media would loop
            # forever, as the unused-row sweep erases the download history
            next if node.name != "img"

            download_src = HotlinkedMedia.download_src_for(node)
            next if !::Chat::MessageHotlinkedMedia.downloadable?(download_src)

            normalized_src = ::Chat::MessageHotlinkedMedia.normalize_src(download_src)
            if (existing = hotlinked_map[normalized_src])
              # still external despite a downloaded row: the localizing re-cook
              # was lost — trigger it again; terminal failures aren't retried
              needs_recook = true if existing.downloaded? && existing.upload
              next
            end

            next if !enough_disk_space?

            status, upload =
              HotlinkedMedia.download(
                download_src,
                chat_message.last_editor_id,
                tmp_file_name: "chat-hotlinked",
              )
            record = upsert_record(chat_message, normalized_src, status, upload)
            hotlinked_map[normalized_src] = record if record
            needs_recook = true if upload && record&.downloaded?
          rescue => e
            raise e if Rails.env.test?
            Discourse.warn_exception(
              e,
              message:
                "Failed to pull hotlinked image (#{download_src}) for chat message #{@chat_message_id}",
            )
          end

        return if !needs_recook

        # the re-cook localizes the images; skip_pull prevents an enqueue loop
        ::Jobs.enqueue(
          ::Jobs::Chat::ProcessMessage,
          chat_message_id: chat_message.id,
          skip_pull_hotlinked_images: true,
          skip_notifications: true,
        )
      end

      def upsert_record(chat_message, normalized_src, status, upload)
        DB.exec(
          <<~SQL,
          INSERT INTO chat_message_hotlinked_media (chat_message_id, url, status, upload_id, created_at, updated_at)
          VALUES (:chat_message_id, :url, :status, :upload_id, NOW(), NOW())
          ON CONFLICT (chat_message_id, md5(url)) DO UPDATE
          SET status = EXCLUDED.status, upload_id = EXCLUDED.upload_id, updated_at = NOW()
          WHERE chat_message_hotlinked_media.upload_id IS NULL AND EXCLUDED.upload_id IS NOT NULL
        SQL
          chat_message_id: chat_message.id,
          url: normalized_src,
          status: status.to_s,
          upload_id: upload&.id,
        )
        ::Chat::MessageHotlinkedMedia.find_by(chat_message_id: chat_message.id, url: normalized_src)
      end

      # `df` forks a process, so only pay for it once there is something to
      # download; the overwhelming majority of messages have nothing.
      def enough_disk_space?
        return @enough_disk_space if defined?(@enough_disk_space)

        disable_if_low_on_disk_space
        @enough_disk_space = SiteSetting.download_remote_images_to_local?
      end

      def disable_if_low_on_disk_space
        return if Discourse.store.external?
        return if !SiteSetting.download_remote_images_to_local
        return if available_disk_space >= SiteSetting.download_remote_images_threshold

        SiteSetting.download_remote_images_to_local = false
        StaffActionLogger.new(Discourse.system_user).log_site_setting_change(
          "download_remote_images_to_local",
          true,
          false,
          details: I18n.t("disable_remote_images_download_reason"),
        )
        SystemMessage.create_from_system_user(
          Discourse.site_contact_user,
          :download_remote_images_disabled,
        )
      end

      def available_disk_space
        100 - DiskSpace.percent_free("#{Rails.public_path.join("uploads")}")
      end
    end
  end
end

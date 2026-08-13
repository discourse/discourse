# frozen_string_literal: true

module Jobs
  module Chat
    class PullHotlinkedImages < ::Jobs::Base
      sidekiq_options queue: "low"

      def execute(args)
        @chat_message_id = args[:chat_message_id]
        raise Discourse::InvalidParameters.new(:chat_message_id) if @chat_message_id.blank?
        return if !SiteSetting.chat_allow_uploads?

        disable_if_low_on_disk_space

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
            download_src = HotlinkedMedia.download_src_for(node)
            next if !should_download?(download_src)

            normalized_src = ::Chat::MessageHotlinkedMedia.normalize_src(download_src)
            if (existing = hotlinked_map[normalized_src])
              # still external despite a downloaded row: the localizing re-cook
              # was lost — trigger it again; terminal failures aren't retried
              needs_recook = true if existing.downloaded? && existing.upload
              next
            end

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
          ON CONFLICT (chat_message_id, md5(url)) DO NOTHING
        SQL
          chat_message_id: chat_message.id,
          url: normalized_src,
          status: status.to_s,
          upload_id: upload&.id,
        )
        ::Chat::MessageHotlinkedMedia.find_by(chat_message_id: chat_message.id, url: normalized_src)
      end

      def should_download?(src)
        return false if src.blank?
        return false if !SiteSetting.download_remote_images_to_local?
        return false if !SiteSetting.chat_allow_uploads?
        return false if src.start_with?("data:")
        # Downloading these means signing an S3 path for the underlying upload.
        # Posts gate that on the author seeing the access-control post; chat
        # messages have none, so there is nothing to authorize against.
        return false if Upload.secure_uploads_url?(src)

        local_bases =
          [
            Discourse.base_url,
            Discourse.asset_host,
            SiteSetting.external_emoji_url.presence,
          ].compact.map { |s| ::Chat::MessageHotlinkedMedia.normalize_src(s) }

        if Discourse.store.has_been_uploaded?(src) ||
             ::Chat::MessageHotlinkedMedia.normalize_src(src).start_with?(*local_bases) ||
             src =~ %r{\A/[^/]}i
          return false if src !~ %r{/uploads/}
          # pass nil: chat messages have no access-control post to reuse against
          upload = Upload.consider_for_reuse(Upload.get_from_url(src), nil)
          return !upload.present?
        end

        begin
          uri = URI.parse(src)
        rescue URI::Error
          return false
        end
        return false if uri.hostname.blank?

        SiteSetting.should_download_images?(src)
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

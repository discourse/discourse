# frozen_string_literal: true

module Jobs
  module Chat
    class PullHotlinkedImages < ::Jobs::Base
      sidekiq_options queue: "low"

      def execute(args)
        @chat_message_id = args[:chat_message_id]
        raise Discourse::InvalidParameters.new(:chat_message_id) if @chat_message_id.blank?

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
        # Don't wipe content for system/webhook messages where cooked is hand-written.
        return if chat_message.message.blank?

        hotlinked_map = chat_message.hotlinked_media.preload(:upload).index_by(&:url)
        uploads_this_run = []

        extract_images(::Nokogiri::HTML5.fragment(chat_message.cooked)).each do |img|
          original_src = img["src"].presence || img[::PrettyText::BLOCKED_HOTLINKED_SRC_ATTR]
          download_src = resolve_download_src(original_src)
          next if !should_download?(download_src)

          normalized_src = ::Chat::MessageHotlinkedMedia.normalize_src(download_src)
          next if hotlinked_map[normalized_src] # already attempted (success or terminal failure)

          status, upload = attempt_download(download_src, chat_message.last_editor_id)
          record = upsert_record(chat_message, normalized_src, status, upload)
          hotlinked_map[normalized_src] = record if record
          uploads_this_run << upload if upload && record&.downloaded?
        rescue => e
          Rails.logger.error(
            "Failed to pull hotlinked image (#{download_src}) for chat message #{@chat_message_id}\n#{e.message}\n#{e.backtrace.join("\n")}",
          )
        end

        # Build the rewrite map from ALL successful records (this run + prior),
        # so a re-introduced URL gets rewritten from cache too.
        uploads_by_url =
          hotlinked_map.each_with_object({}) do |(url, record), acc|
            acc[url] = record.upload if record.downloaded? && record.upload
          end
        return cleanup_orphans(uploads_this_run) if uploads_by_url.empty?

        new_raw =
          ::InlineUploads.replace_hotlinked_image_urls(raw: chat_message.message) do |src|
            uploads_by_url[::Chat::MessageHotlinkedMedia.normalize_src(src)]
          end

        # No raw change means the rewrite couldn't reference what we downloaded
        # (e.g. the image came from an onebox/raw HTML img, not markdown). Destroy
        # any upload we created this run so we don't leak an unreferenced upload;
        # the terminal tracking row stays so we don't re-download on every edit.
        return cleanup_orphans(uploads_this_run) if new_raw == chat_message.message

        # Conditional update — bail if the message changed under us (concurrent
        # user edit). The next ProcessMessage from that edit re-enqueues us, and
        # it will reuse the uploads we created via the cached tracking rows.
        affected =
          ::Chat::Message.where(id: chat_message.id, message: chat_message.message).update_all(
            message: new_raw,
            updated_at: Time.zone.now,
          )
        return if affected.zero?

        new_upload_ids = uploads_by_url.values.compact.map(&:id)
        if new_upload_ids.any?
          # Reload to pick up any concurrently-added UploadReferences before
          # ensure_exist!'s destructive prune.
          chat_message.reload
          ::UploadReference.ensure_exist!(
            upload_ids: (chat_message.upload_ids + new_upload_ids).uniq,
            target_type: ::Chat::Message.polymorphic_name,
            target_id: chat_message.id,
          )
        end

        # Re-cook through ProcessMessage so cooked reflects the rewritten raw —
        # both for fresh downloads and for cache-only rewrites of a re-introduced
        # URL. skip_pull_hotlinked_images prevents an enqueue loop.
        ::Jobs.enqueue(
          ::Jobs::Chat::ProcessMessage,
          chat_message_id: chat_message.id,
          skip_pull_hotlinked_images: true,
          skip_notifications: true,
        )
      end

      # Destroy uploads created this run that never got referenced (the rewrite
      # couldn't place them). Returns nil so callers can `return cleanup_orphans(...)`.
      def cleanup_orphans(uploads)
        uploads.each do |upload|
          upload.destroy if ::UploadReference.where(upload_id: upload.id).none?
        end
        nil
      end

      # Insert tracking row, tolerating a concurrent run that inserted it first.
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

      def extract_images(doc)
        doc.css("img[src], img[#{::PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}]") -
          doc.css("img.avatar") - doc.css("img.emoji") - doc.css(".lightbox img[src]")
      end

      def resolve_download_src(src)
        return src if src.blank?
        return "#{SiteSetting.force_https ? "https" : "http"}:#{src}" if src.start_with?("//")
        src
      end

      def should_download?(src)
        return false if src.blank?
        return false if !SiteSetting.download_remote_images_to_local?
        return false if src.start_with?("data:")

        local_bases =
          [
            Discourse.base_url,
            Discourse.asset_host,
            SiteSetting.external_emoji_url.presence,
          ].compact.map { |s| ::Chat::MessageHotlinkedMedia.normalize_src(s) }

        if Discourse.store.has_been_uploaded?(src) ||
             ::Chat::MessageHotlinkedMedia.normalize_src(src).start_with?(*local_bases) ||
             src =~ %r{\A/[^/]}i
          return false if !(src =~ %r{/uploads/} || Upload.secure_uploads_url?(src))
          # Skip if we already have this upload locally. Chat messages have no
          # access-control-post, so pass nil (don't reuse a post's secured copy).
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

      # Returns [status_symbol, upload_or_nil]. Delegates the actual download to
      # the shared HotlinkedMediaDownloader (used by the post-side job too).
      def attempt_download(src, user_id)
        upload = HotlinkedMediaDownloader.download(src, user_id, tmp_file_name: "chat-hotlinked")
        [:downloaded, upload]
      rescue HotlinkedMediaDownloader::ImageTooLargeError
        [:too_large, nil]
      rescue HotlinkedMediaDownloader::ImageBrokenError
        [:download_failed, nil]
      rescue HotlinkedMediaDownloader::UploadCreateError
        [:upload_create_failed, nil]
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

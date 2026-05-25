# frozen_string_literal: true

module Jobs
  module Chat
    class PullHotlinkedImages < ::Jobs::Base
      sidekiq_options queue: "low"

      def execute(args)
        @chat_message_id = args[:chat_message_id]
        raise Discourse::InvalidParameters.new(:chat_message_id) if @chat_message_id.blank?

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

        original_cooked = chat_message.cooked
        doc = Nokogiri::HTML5.fragment(original_cooked)
        downloads = {} # original src -> Upload
        changed = false

        extract_images(doc).each do |img|
          original_src = img["src"] || img[::PrettyText::BLOCKED_HOTLINKED_SRC_ATTR]
          download_src = resolve_download_src(original_src)
          next if !should_download?(download_src)

          downloads[original_src] ||= attempt_download(download_src, chat_message.last_editor_id)
          upload = downloads[original_src]
          next if upload.nil?

          img["src"] = ::UrlHelper.cook_url(upload.url, secure: upload.secure?)
          img.delete(::PrettyText::BLOCKED_HOTLINKED_SRC_ATTR)
          changed = true
        rescue => e
          Rails.logger.error(
            "Failed to pull hotlinked image (#{download_src}) for chat message #{@chat_message_id}\n#{e.message}\n#{e.backtrace.join("\n")}",
          )
        end

        return if !changed

        new_raw =
          if chat_message.message.present?
            ::InlineUploads.replace_hotlinked_image_urls(raw: chat_message.message) do |src|
              downloads[src]
            end
          else
            chat_message.message
          end

        # Conditional update — bail if cooked changed under us (concurrent edit).
        # The next ProcessMessage triggered by that edit will re-enqueue this job.
        affected_rows =
          ::Chat::Message.where(id: chat_message.id, cooked: original_cooked).update_all(
            message: new_raw,
            cooked: doc.to_html,
            updated_at: Time.zone.now,
          )
        return if affected_rows.zero?

        new_upload_ids = downloads.values.compact.map(&:id)
        if new_upload_ids.any?
          # Reload to pick up any UploadReferences attached by a concurrent edit
          # between our UPDATE and ensure_exist! — otherwise ensure_exist!'s
          # destructive prune would delete them.
          chat_message.reload
          ::UploadReference.ensure_exist!(
            upload_ids: (chat_message.upload_ids + new_upload_ids).uniq,
            target_type: ::Chat::Message.polymorphic_name,
            target_id: chat_message.id,
          )
        end

        chat_message.reload
        ::Chat::Publisher.publish_processed!(chat_message)
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
        return false if src.start_with?("/", "data:")
        return false if Discourse.store.has_been_uploaded?(src)

        begin
          uri = URI.parse(src)
        rescue URI::Error
          return false
        end
        return false if uri.hostname.blank?
        return false if local_hosts.include?(uri.hostname)

        SiteSetting.should_download_images?(src)
      end

      def local_hosts
        @local_hosts ||=
          [
            Discourse.base_url,
            Discourse.asset_host,
            SiteSetting.external_emoji_url.presence,
          ].compact.filter_map do |url|
            URI.parse(url).hostname
          rescue URI::Error
            nil
          end
      end

      def attempt_download(src, user_id)
        downloaded =
          FileHelper.download(
            src,
            max_file_size: SiteSetting.max_image_size_kb.kilobytes,
            retain_on_max_file_size_exceeded: false,
            tmp_file_name: "chat-hotlinked",
            follow_redirect: true,
            read_timeout: 15,
          )
        return nil if downloaded.nil?

        filename = File.basename(URI.parse(src).path)
        filename << File.extname(downloaded.path) if !filename["."]
        upload = ::UploadCreator.new(downloaded, filename, origin: src).create_for(user_id)
        upload.persisted? ? upload : nil
      end
    end
  end
end

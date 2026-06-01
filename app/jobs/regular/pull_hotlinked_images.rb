# frozen_string_literal: true

module Jobs
  class PullHotlinkedImages < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      disable_if_low_on_disk_space

      @post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) if @post_id.blank?

      # in test we have no choice cause we don't want to cause a deadlock
      if Jobs.run_immediately?
        pull_hotlinked_images
      else
        DistributedMutex.synchronize("pull_hotlinked_images_#{@post_id}", validity: 2.minutes) do
          pull_hotlinked_images
        end
      end
    end

    def pull_hotlinked_images
      post = Post.find_by(id: @post_id)
      return if post.nil? || post.topic.nil?

      hotlinked_map = post.post_hotlinked_media.index_by { |r| r.url }

      changed_hotlink_records = false

      extract_images_from(post.cooked).each do |node|
        download_src =
          original_src = node["src"] || node[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR] || node["href"]
        download_src = replace_encoded_src(download_src)
        download_src =
          "#{SiteSetting.force_https ? "https" : "http"}:#{original_src}" if original_src.start_with?(
          "//",
        )
        normalized_src = normalize_src(download_src)

        next if !should_download_image?(download_src, post)

        hotlink_record = hotlinked_map[normalized_src]

        if hotlink_record.nil?
          hotlinked_map[normalized_src] = hotlink_record =
            PostHotlinkedMedia.new(post: post, url: normalized_src)
          begin
            hotlink_record.upload = attempt_download(download_src, post.user_id)
            hotlink_record.status = :downloaded
          rescue ImageTooLargeError
            hotlink_record.status = :too_large
          rescue ImageBrokenError
            hotlink_record.status = :download_failed
          rescue UploadCreateError
            hotlink_record.status = :upload_create_failed
          end
        end

        if hotlink_record.changed?
          changed_hotlink_records = true
          hotlink_record.save!
        end
      rescue => e
        raise e if Rails.env.test?
        log(
          :error,
          "Failed to pull hotlinked image (#{download_src}) post: #{@post_id}\n" + e.message +
            "\n" + e.backtrace.join("\n"),
        )
      end

      if changed_hotlink_records
        post.trigger_post_process(
          bypass_bump: true,
          skip_pull_hotlinked_images: true, # Avoid an infinite loop of job scheduling
        )
      end

      if hotlinked_map.size > 0
        Jobs.cancel_scheduled_job(:update_hotlinked_raw, post_id: post.id)
        update_raw_delay = SiteSetting.editing_grace_period + 1
        Jobs.enqueue_in(update_raw_delay, :update_hotlinked_raw, post_id: post.id)
      end
    end

    # Error classes live on HotlinkedMediaDownloader now; these aliases keep the
    # existing `rescue ImageTooLargeError` call sites (here and in the
    # PullUserProfileHotlinkedImages subclass) working unchanged.
    ImageTooLargeError = HotlinkedMediaDownloader::ImageTooLargeError
    ImageBrokenError = HotlinkedMediaDownloader::ImageBrokenError
    UploadCreateError = HotlinkedMediaDownloader::UploadCreateError

    def attempt_download(src, user_id)
      HotlinkedMediaDownloader.download(src, user_id, tmp_file_name: "discourse-hotlinked")
    end

    def extract_images_from(html)
      doc = Nokogiri::HTML5.fragment(html)

      doc.css("img[src], [#{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}], a.lightbox[href]") -
        doc.css("img.avatar") - doc.css(".lightbox img[src]")
    end

    def should_download_image?(src, post = nil)
      # make sure we actually have a url
      return false if src.blank?

      local_bases =
        [Discourse.base_url, Discourse.asset_host, SiteSetting.external_emoji_url.presence].compact
          .map { |s| normalize_src(s) }

      if Discourse.store.has_been_uploaded?(src) || normalize_src(src).start_with?(*local_bases) ||
           src =~ %r{\A/[^/]}i
        return false if !(src =~ %r{/uploads/} || Upload.secure_uploads_url?(src))

        # Someone could hotlink a file from a different site on the same CDN,
        # so check whether we have it in this database
        #
        # if the upload already exists and is attached to a different post,
        # or the original_sha1 is missing meaning it was created before secure
        # media was enabled, then we definitely want to redownload again otherwise
        # we end up reusing existing uploads which may be linked to many posts
        # already.
        upload = Upload.consider_for_reuse(Upload.get_from_url(src), post)

        return !upload.present?
      end

      # Don't download non-local images unless site setting enabled
      return false unless SiteSetting.download_remote_images_to_local?

      # parse the src
      begin
        uri = URI.parse(src)
      rescue URI::Error
        return false
      end

      hostname = uri.hostname
      return false unless hostname

      # check the domains blocklist
      SiteSetting.should_download_images?(src)
    end

    def log(log_level, message)
      Rails.logger.public_send(
        log_level,
        "#{RailsMultisite::ConnectionManagement.current_db}: #{message}",
      )
    end

    protected

    def replace_encoded_src(src)
      PostHotlinkedMedia.normalize_src(src, reset_scheme: false)
    end

    def normalize_src(src)
      PostHotlinkedMedia.normalize_src(src)
    end

    def disable_if_low_on_disk_space
      return if Discourse.store.external?
      return if !SiteSetting.download_remote_images_to_local
      return if available_disk_space >= SiteSetting.download_remote_images_threshold

      SiteSetting.download_remote_images_to_local = false

      # log the site setting change
      reason = I18n.t("disable_remote_images_download_reason")
      staff_action_logger = StaffActionLogger.new(Discourse.system_user)
      staff_action_logger.log_site_setting_change(
        "download_remote_images_to_local",
        true,
        false,
        details: reason,
      )

      # also send a private message to the site contact user notify_about_low_disk_space
      notify_about_low_disk_space
    end

    def notify_about_low_disk_space
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

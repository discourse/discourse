# frozen_string_literal: true

module Jobs

  class PullHotlinkedImages < ::Jobs::Base
    sidekiq_options queue: 'low'

    def initialize
      @max_size = SiteSetting.max_image_size_kb.kilobytes
    end

    def execute(args)
      @post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) if @post_id.blank?

      post = Post.find_by(id: @post_id)
      return if post.blank?
      return if post.topic.blank?

      raw = post.raw.dup
      start_raw = raw.dup

      large_image_urls = post.custom_fields[Post::LARGE_IMAGES] || []
      broken_image_urls = post.custom_fields[Post::BROKEN_IMAGES] || []
      downloaded_image_ids = post.custom_fields[Post::DOWNLOADED_IMAGES] || {}

      upload_records = Upload.where(id: downloaded_image_ids.values)
      upload_records = Hash[upload_records.map { |u| [u.id, u] }]

      downloaded_images = {}
      downloaded_image_ids.each { |url, id| downloaded_images[url] = upload_records[id] }

      extract_images_from(post.cooked).each do |node|
        download_src = original_src = node['src'] || node['href']
        download_src = "#{SiteSetting.force_https ? "https" : "http"}:#{original_src}" if original_src.start_with?("//")
        normalized_src = normalize_src(download_src)

        next if !should_download_image?(download_src, post)

        begin
          already_attempted_download = downloaded_images.include?(normalized_src) || large_image_urls.include?(normalized_src) || broken_image_urls.include?(normalized_src)
          if !already_attempted_download
            downloaded_images[normalized_src] = attempt_download(download_src, post.user_id)
          end
        rescue ImageTooLargeError
          large_image_urls << normalized_src
        rescue ImageBrokenError
          broken_image_urls << normalized_src
        end

        # have we successfully downloaded that file?
        if upload = downloaded_images[normalized_src]
          raw = replace_in_raw(original_src: original_src, upload: upload, raw: raw)
        end
      rescue => e
        raise e if Rails.env.test?
        log(:error, "Failed to pull hotlinked image (#{download_src}) post: #{@post_id}\n" + e.message + "\n" + e.backtrace.join("\n"))
      end

      large_image_urls.uniq!
      broken_image_urls.uniq!
      downloaded_images.compact!

      post.custom_fields[Post::LARGE_IMAGES] = large_image_urls
      post.custom_fields[Post::BROKEN_IMAGES] = broken_image_urls

      downloaded_image_ids = {}
      downloaded_images.each { |url, upload| downloaded_image_ids[url] = upload.id }
      post.custom_fields[Post::DOWNLOADED_IMAGES] = downloaded_image_ids

      [Post::LARGE_IMAGES, Post::BROKEN_IMAGES, Post::DOWNLOADED_IMAGES].each do |key|
        post.custom_fields.delete(key) if !post.custom_fields[key].present?
      end

      custom_fields_updated = !post.custom_fields_clean?

      # only save custom fields if they changed
      post.save_custom_fields if custom_fields_updated

      # If post changed while we were downloading images, never apply edits
      post.reload
      post_changed_elsewhere = (start_raw != post.raw)
      raw_changed_here = (raw != post.raw)

      if !post_changed_elsewhere && raw_changed_here
        changes = { raw: raw, edit_reason: I18n.t("upload.edit_reason") }
        post.revise(Discourse.system_user, changes, bypass_bump: true, skip_staff_log: true)
      elsif custom_fields_updated
        post.trigger_post_process(
          bypass_bump: true,
          skip_pull_hotlinked_images: true # Avoid an infinite loop of job scheduling
        )
      end
    end

    def download(src)
      downloaded = nil

      begin
        retries ||= 3

        if SiteSetting.verbose_upload_logging
          Rails.logger.warn("Verbose Upload Logging: Downloading hotlinked image from #{src}")
        end

        downloaded = FileHelper.download(
          src,
          max_file_size: @max_size,
          retain_on_max_file_size_exceeded: true,
          tmp_file_name: "discourse-hotlinked",
          follow_redirect: true
        )
      rescue
        if (retries -= 1) > 0 && !Rails.env.test?
          sleep 1
          retry
        end
      end

      downloaded
    end

    class ImageTooLargeError < StandardError; end
    class ImageBrokenError < StandardError; end

    def attempt_download(src, user_id)
      # secure-media-uploads endpoint prevents anonymous downloads, so we
      # need the presigned S3 URL here
      src = Upload.signed_url_from_secure_media_url(src) if Upload.secure_media_url?(src)

      hotlinked = download(src)
      raise ImageBrokenError if !hotlinked
      raise ImageTooLargeError if File.size(hotlinked.path) > @max_size

      filename = File.basename(URI.parse(src).path)
      filename << File.extname(hotlinked.path) unless filename["."]
      upload = UploadCreator.new(hotlinked, filename, origin: src).create_for(user_id)

      if upload.persisted?
        upload
      else
        log(:info, "Failed to persist downloaded hotlinked image for post: #{@post_id}: #{src} - #{upload.errors.full_messages.join("\n")}")
        nil
      end
    end

    def replace_in_raw(original_src:, raw:, upload:)
      raw = raw.dup
      escaped_src = Regexp.escape(original_src)

      replace_raw = ->(match, match_src, replacement, _index) {
        if normalize_src(original_src) == normalize_src(match_src)
          replacement =
            if replacement.include?(InlineUploads::PLACEHOLDER)
              replacement.sub(InlineUploads::PLACEHOLDER, upload.short_url)
            elsif replacement.include?(InlineUploads::PATH_PLACEHOLDER)
              replacement.sub(InlineUploads::PATH_PLACEHOLDER, upload.short_path)
            end

          raw = raw.gsub(
            match,
            replacement
          )
        end
      }

      # there are 6 ways to insert an image in a post
      # HTML tag - <img src="http://...">
      InlineUploads.match_img(raw, external_src: true, &replace_raw)

      # BBCode tag - [img]http://...[/img]
      InlineUploads.match_bbcode_img(raw, external_src: true, &replace_raw)

      # Markdown linked image - [![alt](http://...)](http://...)
      # Markdown inline - ![alt](http://...)
      # Markdown inline - ![](http://... "image title")
      # Markdown inline - ![alt](http://... "image title")
      InlineUploads.match_md_inline_img(raw, external_src: true, &replace_raw)

      # Direct link
      raw.gsub!(/^#{escaped_src}(\s?)$/) { "![](#{upload.short_url})#{$1}" }

      raw
    end

    def extract_images_from(html)
      doc = Nokogiri::HTML5::fragment(html)

      doc.css("img[src], a.lightbox[href]") -
        doc.css("img.avatar") -
        doc.css(".lightbox img[src]")
    end

    def should_download_image?(src, post = nil)
      # make sure we actually have a url
      return false unless src.present?

      local_bases = [
        Discourse.base_url,
        Discourse.asset_host,
        SiteSetting.external_emoji_url.presence
      ].compact.map { |s| normalize_src(s) }

      if Discourse.store.has_been_uploaded?(src) || normalize_src(src).start_with?(*local_bases) || src =~ /\A\/[^\/]/i
        return false if !(src =~ /\/uploads\// || Upload.secure_media_url?(src))

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
        "#{RailsMultisite::ConnectionManagement.current_db}: #{message}"
      )
    end

    private

    def normalize_src(src)
      uri = Addressable::URI.heuristic_parse(src)
      uri.normalize!
      uri.scheme = nil
      uri.to_s
    rescue URI::Error, Addressable::URI::InvalidURIError
      src
    end
  end

end

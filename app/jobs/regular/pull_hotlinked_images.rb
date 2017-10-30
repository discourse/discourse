require_dependency 'url_helper'
require_dependency 'file_helper'
require_dependency 'upload_creator'

module Jobs

  class PullHotlinkedImages < Jobs::Base

    sidekiq_options queue: 'low'

    def initialize
      @max_size = SiteSetting.max_image_size_kb.kilobytes
    end

    def download(src)
      downloaded = nil

      begin
        retries ||= 3

        downloaded = FileHelper.download(
          src,
          max_file_size: @max_size,
          tmp_file_name: "discourse-hotlinked",
          follow_redirect: true
        )
      rescue
        if (retries -= 1) > 0
          sleep 1
          retry
        end
      end

      downloaded
    end

    def execute(args)
      return unless SiteSetting.download_remote_images_to_local?

      post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) unless post_id.present?

      post = Post.find_by(id: post_id)
      return unless post.present?

      raw = post.raw.dup
      start_raw = raw.dup
      downloaded_urls = {}
      broken_images, large_images = [], []

      extract_images_from(post.cooked).each do |image|
        src = original_src = image['src']
        if src.start_with?("//")
          src = "#{SiteSetting.force_https ? "https" : "http"}:#{src}"
        end

        if is_valid_image_url(src)
          begin
            # have we already downloaded that file?
            unless downloaded_urls.include?(src)
              if hotlinked = download(src)
                if File.size(hotlinked.path) <= @max_size
                  filename = File.basename(URI.parse(src).path)
                  filename << File.extname(hotlinked.path) unless filename["."]
                  upload = UploadCreator.new(hotlinked, filename, origin: src).create_for(post.user_id)
                  if upload.persisted?
                    downloaded_urls[src] = upload.url
                  else
                    log(:info, "Failed to pull hotlinked image for post: #{post_id}: #{src} - #{upload.errors.full_messages.join("\n")}")
                  end
                else
                  large_images << original_src
                end
              else
                broken_images << original_src
              end
            end
            # have we successfully downloaded that file?
            if downloaded_urls[src].present?
              url = downloaded_urls[src]
              escaped_src = Regexp.escape(original_src)
              # there are 6 ways to insert an image in a post
              # HTML tag - <img src="http://...">
              raw.gsub!(/src=["']#{escaped_src}["']/i, "src='#{url}'")
              # BBCode tag - [img]http://...[/img]
              raw.gsub!(/\[img\]#{escaped_src}\[\/img\]/i, "[img]#{url}[/img]")
              # Markdown linked image - [![alt](http://...)](http://...)
              raw.gsub!(/\[!\[([^\]]*)\]\(#{escaped_src}\)\]/) { "[<img src='#{url}' alt='#{$1}'>]" }
              # Markdown inline - ![alt](http://...)
              raw.gsub!(/!\[([^\]]*)\]\(#{escaped_src}\)/) { "![#{$1}](#{url})" }
              # Markdown inline - ![](http://... "image title")
              raw.gsub!(/!\[\]\(#{escaped_src} "([^\]]*)"\)/) { "![](#{url})" }
              # Markdown inline - ![alt](http://... "image title")
              raw.gsub!(/!\[([^\]]*)\]\(#{escaped_src} "([^\]]*)"\)/) { "![](#{url})" }
              # Markdown reference - [x]: http://
              raw.gsub!(/\[([^\]]+)\]:\s?#{escaped_src}/) { "[#{$1}]: #{url}" }
              # Direct link
              raw.gsub!(/^#{escaped_src}(\s?)$/) { "<img src='#{url}'>#{$1}" }
            end
          rescue => e
            log(:error, "Failed to pull hotlinked image (#{src}) post: #{post_id}\n" + e.message + "\n" + e.backtrace.join("\n"))
          end
        end

      end

      post.reload
      if start_raw == post.raw && raw != post.raw
        changes = { raw: raw, edit_reason: I18n.t("upload.edit_reason") }
        # we never want that job to bump the topic
        options = { bypass_bump: true }
        post.revise(Discourse.system_user, changes, options)
      elsif downloaded_urls.present?
        post.trigger_post_process(true)
      elsif broken_images.present? || large_images.present?
        start_html = post.cooked
        doc = Nokogiri::HTML::fragment(start_html)
        images = doc.css("img[src]") - doc.css("img.avatar")
        images.each do |tag|
          src = tag['src']
          if broken_images.include?(src)
            tag.name = 'span'
            tag.set_attribute('class', 'broken-image fa fa-chain-broken')
            tag.set_attribute('title', I18n.t('post.image_placeholder.broken'))
            tag.remove_attribute('src')
            tag.remove_attribute('width')
            tag.remove_attribute('height')
          elsif large_images.include?(src)
            tag.name = 'a'
            tag.set_attribute('href', src)
            tag.set_attribute('target', '_blank')
            tag.set_attribute('title', I18n.t('post.image_placeholder.large'))
            tag.remove_attribute('src')
            tag.remove_attribute('width')
            tag.remove_attribute('height')
            tag.inner_html = '<span class="large-image fa fa-picture-o"></span>'
            parent = tag.parent
            if parent.name == 'a'
              parent.add_next_sibling(tag)
              parent.add_next_sibling('<br>')
              parent.content = parent["href"]
            end
          end
        end
        if start_html == post.cooked && doc.to_html != post.cooked
          post.update_column(:cooked, doc.to_html)
          post.publish_change_to_clients! :revised
        end
      end
    end

    def extract_images_from(html)
      doc = Nokogiri::HTML::fragment(html)
      doc.css("img[src]") - doc.css("img.avatar")
    end

    def is_valid_image_url(src)
      # make sure we actually have a url
      return false unless src.present?
      # we don't want to pull uploaded images
      return false if Discourse.store.has_been_uploaded?(src)
      # we don't want to pull relative images
      return false if src =~ /\A\/[^\/]/i

      # parse the src
      begin
        uri = URI.parse(src)
      rescue URI::InvalidURIError
        return false
      end

      hostname = uri.hostname
      return false unless hostname

      # we don't want to pull images hosted on the CDN (if we use one)
      return false if Discourse.asset_host.present? && URI.parse(Discourse.asset_host).hostname == hostname
      return false if SiteSetting.Upload.s3_cdn_url.present? && URI.parse(SiteSetting.Upload.s3_cdn_url).hostname == hostname
      # we don't want to pull images hosted on the main domain
      return false if URI.parse(Discourse.base_url_no_prefix).hostname == hostname
      # check the domains blacklist
      SiteSetting.should_download_images?(src)
    end

    def log(log_level, message)
      Rails.logger.public_send(
        log_level,
        "#{RailsMultisite::ConnectionManagement.current_db}: #{message}"
      )
    end

  end

end

require_dependency 'url_helper'

module Jobs

  class PullHotlinkedImages < Jobs::Base
    include UrlHelper

    def initialize
      # maximum size of the file in bytes
      @max_size = SiteSetting.max_image_size_kb.kilobytes
    end

    def execute(args)
      return unless SiteSetting.download_remote_images_to_local?

      post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) unless post_id.present?

      post = Post.where(id: post_id).first
      return unless post.present?

      raw = post.raw.dup
      downloaded_urls = {}

      extract_images_from(post.cooked).each do |image|
        src = image['src']
        src = "http:" + src if src.start_with?("//")

        if is_valid_image_url(src)
          begin
            # have we already downloaded that file?
            if !downloaded_urls.include?(src)
              hotlinked = download(src)
              if hotlinked.try(:size) <= @max_size
                filename = File.basename(URI.parse(src).path)
                file = ActionDispatch::Http::UploadedFile.new(tempfile: hotlinked, filename: filename)
                upload = Upload.create_for(post.user_id, file, hotlinked.size, src)
                downloaded_urls[src] = upload.url
              else
                puts "Failed to pull hotlinked image: #{src} - Image is bigger than #{@max_size}"
              end
            end
            # have we successfuly downloaded that file?
            if downloaded_urls[src].present?
              url = downloaded_urls[src]
              escaped_src = src.gsub("?", "\\?").gsub(".", "\\.").gsub("+", "\\+")
              # there are 6 ways to insert an image in a post
              # HTML tag - <img src="http://...">
              raw.gsub!(/src=["']#{escaped_src}["']/i, "src='#{url}'")
              # BBCode tag - [img]http://...[/img]
              raw.gsub!(/\[img\]#{escaped_src}\[\/img\]/i, "[img]#{url}[/img]")
              # Markdown linked image - [![alt](http://...)](http://...)
              raw.gsub!(/\[!\[([^\]]*)\]\(#{escaped_src}\)\]/) { "[<img src='#{url}' alt='#{$1}'>]" }
              # Markdown inline - ![alt](http://...)
              raw.gsub!(/!\[([^\]]*)\]\(#{escaped_src}\)/) { "![#{$1}](#{url})" }
              # Markdown reference - [x]: http://
              raw.gsub!(/\[(\d+)\]: #{escaped_src}/) { "[#{$1}]: #{url}" }
              # Direct link
              raw.gsub!(src, "<img src='#{url}'>")
            end
          rescue => e
            puts "Failed to pull hotlinked image: #{src}\n" + e.message + "\n" + e.backtrace.join("\n")
          ensure
            # close & delete the temp file
            hotlinked && hotlinked.close!
          end
        end

      end

      # TODO: make sure the post hasn´t changed while we were downloading remote images
      if raw != post.raw
        options = { edit_reason: I18n.t("upload.edit_reason") }
        options[:bypass_bump] = true if args[:bypass_bump] == true
        post.revise(Discourse.system_user, raw, options)
      end
    end

    def extract_images_from(html)
      doc = Nokogiri::HTML::fragment(html)
      doc.css("img") - doc.css(".onebox-result img") - doc.css("img.avatar")
    end

    def is_valid_image_url(src)
      src.present? && !Discourse.store.has_been_uploaded?(src)
    end

    def download(url)
      return if @max_size <= 0
      extension = File.extname(URI.parse(url).path)
      tmp = Tempfile.new(["discourse-hotlinked", extension])

      File.open(tmp.path, "wb") do |f|
        hotlinked = open(url, "rb", read_timeout: 5)
        while f.size <= @max_size && data = hotlinked.read(@max_size)
          f.write(data)
        end
        hotlinked.close!
      end

      tmp
    end

  end

end

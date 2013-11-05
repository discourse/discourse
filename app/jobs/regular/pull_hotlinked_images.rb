module Jobs

  class PullHotlinkedImages < Jobs::Base

    def initialize
      # maximum size of the file in bytes
      @max_size = SiteSetting.max_image_size_kb * 1024
    end

    def execute(args)
      # we don't want to run the job if we're not allowed to crawl images
      return unless SiteSetting.crawl_images?

      post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) unless post_id.present?

      post = Post.where(id: post_id).first
      return unless post.present?

      raw = post.raw.dup
      downloaded_urls = {}

      extract_images_from(post.cooked).each do |image|
        src = image['src']

        if is_valid_image_url(src)
          begin
            # have we already downloaded that file?
            if !downloaded_urls.include?(src)
              hotlinked = download(src)
              if hotlinked.size <= @max_size
                filename = File.basename(URI.parse(src).path)
                file = ActionDispatch::Http::UploadedFile.new(tempfile: hotlinked, filename: filename)
                upload = Upload.create_for(post.user_id, file, hotlinked.size, src)
                downloaded_urls[src] = upload.url
              else
                Rails.logger.warn("Failed to pull hotlinked image: #{src} - Image is bigger than #{@max_size}")
              end
            end
            # have we successfuly downloaded that file?
            if downloaded_urls[src].present?
              url = downloaded_urls[src]
              escaped_src = src.gsub("?", "\\?").gsub(".", "\\.").gsub("+", "\\+")
              # there are 5 ways to insert an image in a post
              # HTML tag - <img src="http://...">
              raw.gsub!(/src=["']#{escaped_src}["']/i, "src='#{url}'")
              # BBCode tag - [img]http://...[/img]
              raw.gsub!(/\[img\]#{escaped_src}\[\/img\]/i, "[img]#{url}[/img]")
              # Markdown inline - ![alt](http://...)
              raw.gsub!(/!\[([^\]]*)\]\(#{escaped_src}\)/) { "![#{$1}](#{url})" }
              # Markdown reference - [x]: http://
              raw.gsub!(/\[(\d+)\]: #{escaped_src}/) { "[#{$1}]: #{url}" }
              # Direct link
              raw.gsub!(src, "<img src='#{url}'>")
            end
          rescue => e
            Rails.logger.error("Failed to pull hotlinked image: #{src}\n" + e.message + "\n" + e.backtrace.join("\n"))
          ensure
            # close & delete the temp file
            hotlinked && hotlinked.close!
          end
        end

      end

      # TODO: make sure the post hasn´t changed while we were downloading remote images
      if raw != post.raw
        options = { force_new_version: true }
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

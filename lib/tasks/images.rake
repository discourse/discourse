task "images:compress" => :environment do
  io = ImageOptim.new
  images = Dir.glob("#{Rails.root}/app/**/*.png")
  image_sizes = Hash[*images.map{|i| [i,File.size(i)]}.to_a.flatten]
  io.optimize_images!(images) do |name, optimized|
    if optimized
      new_size = File.size(name)
      puts "#{name} => from: #{image_sizes[name.to_s]} to: #{new_size}"
    end
  end
end

desc "download all hotlinked images"
task "images:pull_hotlinked" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    # currently only works when using the local storage
    next if Discourse.store.external?

    puts "Pulling hotlinked images for: #{db}"

    # shorthand to the asset host
    asset_host = Rails.configuration.action_controller.asset_host
    # maximum size of the file in bytes
    max_size = SiteSetting.max_image_size_kb * 1024
    # will hold the urls of the already downloaded images
    upload_urls = {}

    Post.find_each do |post|
      has_changed = false

      extract_images_from(post.cooked).each do |image|
        src = image['src']
        if src.present? &&
           src !~ /^\/[^\/]/ &&
           !src.starts_with?(Discourse.base_url_no_prefix) &&
           !(asset_host.present? && src.starts_with?(asset_host))
          begin
            # have we already downloaded that file?
            if !upload_urls.include?(src)
              # initialize
              upload_urls[src] = nil
              # download the file
              hotlinked = download(src, max_size)
              # if the hotlinked image is OK
              if hotlinked.size <= max_size
                file = ActionDispatch::Http::UploadedFile.new(tempfile: hotlinked, filename: File.basename(URI.parse(src).path))
                upload_urls[src] = Upload.create_for(post.user_id, file, hotlinked.size).url
              else
                puts "\nFailed to pull: #{src} for post ##{post.id} - too large\n"
              end
            end
            # if we have downloaded a file
            if upload_urls[src].present?
              src_for_regexp = src.gsub("?", "\\?").gsub(".", "\\.").gsub("+", "\\+")
              # there are 5 ways to insert an image in a post
              # HTML tag - <img src="http://...">
              post.raw.gsub!(/src=["']#{src_for_regexp}["']/i, "src='#{upload_urls[src]}'")
              # BBCode tag - [img]http://...[/img]
              post.raw.gsub!(/\[img\]#{src_for_regexp}\[\/img\]/i, "[img]#{upload_urls[src]}[/img]")
              # Markdown inline - ![alt](http://...)
              post.raw.gsub!(/!\[([^\]]*)\]\(#{src_for_regexp}\)/) { "![#{$1}](#{upload_urls[src]})" }
              # Markdown reference - [x]: http://
              post.raw.gsub!(/\[(\d+)\]: #{src_for_regexp}/) { "[#{$1}]: #{upload_urls[src]}" }
              # Direct link
              post.raw.gsub!(src, "<img src='#{upload_urls[src]}'>")
              # mark the post as changed
              has_changed = true
            end
          rescue => e
            puts "\nFailed to pull: #{src} for post ##{post.id} - #{e}\n"
          ensure
            # close & delete the temporary file
            hotlinked && hotlinked.close!
          end
        end
      end

      if has_changed
        # since the raw has changed, we cook the post once again
        post.cooked = post.cook(post.raw, topic_id: post.topic_id, invalidate_oneboxes: true)
        # update both raw & cooked version of the post
        Post.exec_sql('update posts set cooked = ?, raw = ? where id = ?', post.cooked, post.raw, post.id)
        # trigger the post processing
        post.trigger_post_process
        putc "#"
      else
        putc "."
      end
    end
  end
  puts "\ndone."
end

def extract_images_from(html)
  doc = Nokogiri::HTML::fragment(html)
  doc.css("img") - doc.css(".onebox-result img") - doc.css("img.avatar")
end

def download(url, max_size)
  # create a temporary file
  temp_file = Tempfile.new(["discourse-hotlinked", File.extname(URI.parse(url).path)])
  # download the hotlinked image
  File.open(temp_file.path, "wb") do |f|
    hotlinked = open(url, "rb", read_timeout: 5)
    while f.size <= max_size && data = hotlinked.read(max_size)
      f.write(data)
    end
    hotlinked.close
  end
  temp_file
end

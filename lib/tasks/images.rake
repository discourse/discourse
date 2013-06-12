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

desc "updates reverse index of image uploads"
task "images:reindex" => :environment do
	RailsMultisite::ConnectionManagement.each_connection do |db|
		puts "Reindexing #{db}"
    Post.select([:id, :cooked]).find_each do |p|
			doc = Nokogiri::HTML::fragment(p.cooked)
			doc.search("img").each do |img|
				src = img['src']
				if src.present? && has_been_uploaded?(src) && m = uploaded_regex.match(src)
          begin
  					Post.exec_sql("INSERT INTO posts_uploads (post_id, upload_id) VALUES (?, ?)", p.id, m[:upload_id])
          rescue ActiveRecord::RecordNotUnique
          end
				end
			end
			putc "."
		end
  end
  puts "\ndone."
end

def uploaded_regex
  /\/uploads\/#{RailsMultisite::ConnectionManagement.current_db}\/(?<upload_id>\d+)\/[0-9a-f]{16}\.(png|jpg|jpeg|gif|tif|tiff|bmp)/
end

def has_been_uploaded?(url)
  url =~ /^\/[^\/]/ || url.start_with?(base_url) || (asset_host.present? && url.start_with?(asset_host))
end

def base_url
  asset_host.present? ? asset_host : Discourse.base_url_no_prefix
end

def asset_host
  ActionController::Base.asset_host
end

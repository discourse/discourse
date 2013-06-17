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
				if src.present? && Upload.has_been_uploaded?(src) && m = Upload.uploaded_regex.match(src)
          begin
            PostUpload.create({ post_id: p.id, upload_id: m[:upload_id] })
          rescue ActiveRecord::RecordNotUnique
          end
				end
			end
      putc "."
		end
  end
  puts "\ndone."
end

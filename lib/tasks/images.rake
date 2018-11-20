require_dependency "file_helper"

task "images:compress" => :environment do
  images = Dir.glob("#{Rails.root}/app/**/*.png")
  image_sizes = Hash[*images.map { |i| [i, File.size(i)] }.to_a.flatten]
  FileHelper.optimize_images!(images) do |name, optimized|
    if optimized
      new_size = File.size(name)
      puts "#{name} => from: #{image_sizes[name.to_s]} to: #{new_size}"
    end
  end
end

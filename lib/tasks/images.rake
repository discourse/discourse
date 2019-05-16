# frozen_string_literal: true

require_dependency "file_helper"

task "images:compress" => :environment do
  images = Dir.glob("#{Rails.root}/app/**/*.png")
  image_sizes = images.map { |i| [i, File.size(i)] }.to_h

  images.each do |path|
    if FileHelper.optimize_image!(path)
      new_size = File.size(path)
      puts "#{path} => from: #{image_sizes[path]} to: #{new_size}"
    end
  end
end

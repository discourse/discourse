require "open3"
require "json"
require "tmpdir"
require "vips"
require_relative "jpeg_quality"

checks = []
source = "spec/fixtures/images/exif_orientation.jpg"
Dir.mktmpdir("jpeg-quality-") do |directory|
  [false, true].product([false, true]).each do |grayscale, progressive|
    (1..100).each do |quality|
      path = File.join(directory, "sample.jpg")
      _, stderr, status = Open3.capture3(
        "magick", source, "-colorspace", grayscale ? "gray" : "sRGB",
        "-interlace", progressive ? "plane" : "none", "-quality", quality.to_s, path,
      )
      raise stderr if !status.success?
      expected, status = Open3.capture2("identify", "-ping", "-format", "%Q", path)
      raise "identify failed" if !status.success?
      actual = DiscourseVips::JpegQuality.estimate(path)
      checks << { encoder: "imagemagick", quality:, grayscale:, progressive:, expected: expected.to_i, actual: }
    end
  end
  image = Vips::Image.new_from_file(source)
  (1..100).each do |quality|
    path = File.join(directory, "jpegli.jpg")
    image.jpegsave(path, Q: quality)
    expected, status = Open3.capture2("identify", "-ping", "-format", "%Q", path)
    raise "identify failed" if !status.success?
    checks << { encoder: "jpegli", quality:, expected: expected.to_i, actual: DiscourseVips::JpegQuality.estimate(path) }
  end
end
mismatches = checks.reject { |check| check[:expected] == check[:actual] }
File.write("public/discourse-task/jpeg-quality-matrix.json", JSON.pretty_generate({ checks:, mismatches: }))
puts JSON.generate({ checks: checks.size, mismatches: })
raise "quality mismatches" if !mismatches.empty?

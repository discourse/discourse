require "json"
require "digest"
require "open3"
require "chunky_png"
require "vips"

Vips.cache_set_max(0)
Vips.concurrency_set(1)

root = Rails.root.join("public/discourse-task/jpeg-evidence")
FileUtils.mkdir_p(root)

def command(*arguments)
  stdout, stderr, status = Open3.capture3(*arguments.map(&:to_s))
  raise "#{arguments.first}: #{stderr}" unless status.success?
  stdout
end

def inspect_image(path)
  format = "%m|%w|%h|%[colorspace]|%z|%Q|%[profiles]|%[pixel:p{0,0}]|%[pixel:p{32,32}]"
  details = command("identify", "-format", format, path).split("|")
  { path: path.to_s, pixels: details[1].to_i * details[2].to_i, bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest, details: details }
end

profile = Rails.root.join("vendor/data/RT_sRGB.icm")
base = root.join("source.png")
canvas = ChunkyPNG::Image.new(64, 64)
64.times do |row|
  64.times do |column|
    canvas[column, row] = ChunkyPNG::Color.rgb(224 - row * 3, 48 + row / 4, 32 + row * 3)
  end
end
canvas.save(base.to_s)
tagged = Vips::Image.pngload(base.to_s).copy
icc_bytes = File.binread(profile)
tagged.set_type(Vips::BLOB_TYPE, "icc-profile-data", icc_bytes)
raise "in-memory ICC profile missing" if tagged.get_typeof("icc-profile-data").zero?
raise "in-memory ICC bytes changed" unless tagged.get("icc-profile-data") == icc_bytes
tagged.pngsave(root.join("source-profile.png").to_s)
raise "saved ICC profile missing" if Vips::Image.pngload(root.join("source-profile.png").to_s).get_typeof("icc-profile-data").zero?
FileUtils.mv(root.join("source-profile.png"), base)
raise "source ICC profile missing" if Vips::Image.pngload(base.to_s).get_typeof("icc-profile-data").zero?
command("magick", base, "-quality", "95", root.join("rgb.jpg"))
command("magick", base, "-colorspace", "gray", "-quality", "95", root.join("gray.jpg"))
command("magick", base, "+profile", "*", "-colorspace", "CMYK", "-quality", "95", root.join("cmyk.jpg"))
alpha_source = root.join("alpha.png")
ChunkyPNG::Image.new(64, 64, ChunkyPNG::Color.rgba(255, 0, 0, 128)).save(alpha_source.to_s)
command("magick", alpha_source, "-depth", "16", "-define", "png:bit-depth=16", root.join("alpha16.png"))
command("magick", base, root.join("static.gif"))
command("magick", base, root.join("static.webp"))
command("magick", base, root.join("static.avif"))

cases = [["source.png", "png"], ["rgb.jpg", "jpeg"], ["gray.jpg", "jpeg"], ["cmyk.jpg", "jpeg"], ["alpha16.png", "png"], ["static.gif", "gif"], ["static.webp", "webp"], ["static.avif", "avif"]]
FileUtils.cp(Rails.root.join("spec/fixtures/images/huge.jpg"), root.join("stress.jpg"))
cases << ["stress.jpg", "jpeg"]
photo = Vips::Image.heifload(Rails.root.join("spec/fixtures/images/should_be_jpeg.heic").to_s, n: 1).autorot
photo.jpegsave(root.join("photo.jpg").to_s, Q: 95)
cases << ["photo.jpg", "jpeg"]
photo = photo.copy
photo.set_type(Vips::BLOB_TYPE, "icc-profile-data", icc_bytes)
photo.jpegsave(root.join("photo-profile.jpg").to_s, Q: 95)
raise "photo ICC profile missing" if Vips::Image.jpegload(root.join("photo-profile.jpg").to_s).get_typeof("icc-profile-data").zero?
cases << ["photo-profile.jpg", "jpeg"]
raise "source dimensions changed" unless FastImage.size(base) == [64, 64]
raise "photo dimensions changed" unless FastImage.size(root.join("photo.jpg")) == [photo.width, photo.height]
raise "alpha fixture is not 16-bit" unless Vips::Image.pngload(root.join("alpha16.png").to_s).format == :ushort
cmyk_profile = Dir.glob("/usr/share/color/icc/**/*", File::FNM_CASEFOLD).find { |path| File.file?(path) && File.basename(path).match?(/cmyk|fogra|swop/i) }
if cmyk_profile
  cmyk = Vips::Image.jpegload(root.join("cmyk.jpg").to_s).copy
  cmyk.set_type(Vips::BLOB_TYPE, "icc-profile-data", File.binread(cmyk_profile))
  cmyk.jpegsave(root.join("cmyk-profile.jpg").to_s, Q: 95)
  cases << ["cmyk-profile.jpg", "jpeg"]
end

results = cases.map do |filename, input_format|
  input = root.join(filename)
  im_output = root.join("#{filename}.im.jpg")
  vips_output = root.join("#{filename}.vips.jpg")
  record = { input: inspect_image(input) }
  if ["source.png", "photo-profile.jpg", "cmyk-profile.jpg"].include?(filename)
    raise "expected ICC profile missing from #{filename}" unless record[:input][:details][6].to_s.include?("icc")
  end
  begin
    ImageMagick.magick(
      "#{input_format}:#{input}", "-auto-orient", "-background", "white", "-interlace", "none", "-flatten", "-quality", "75", "jpg:#{im_output}",
      operation: :upload_format_conversion, read: [input.to_s], write: [root.to_s], timeout: 20,
    )
    DiscourseVips.convert_to_jpeg(input_path: input.to_s, output_path: vips_output.to_s, input_format: input_format, quality: 75, timeout: 20)
    record[:imagemagick] = inspect_image(im_output)
    record[:vips] = inspect_image(vips_output)
    previews = [im_output, vips_output].map do |path|
      sample = "#{path}.png"
      command("magick", path, "-colorspace", "sRGB", "-depth", "8", sample)
      sample
    end
    preview_dimensions = previews.map { |path| FastImage.size(path) }
    record[:preview_dimensions] = preview_dimensions
    if preview_dimensions[0] != preview_dimensions[1]
      record[:comparison_error] = "output dimensions differ"
    else
      rasters = previews.map do |path|
        Vips::Image.pngload(path, access: :sequential).colourspace(:srgb).cast(:uchar)
      end
      differences = (rasters[0] - rasters[1]).abs
      statistics = differences.stats
      record[:rgb_mae] = statistics.getpoint(4, 0).first
      record[:rgb_max_error] = statistics.getpoint(1, 0).first
    end
    record[:postprocessing] = {}
    [false, true].each do |strip|
      record[:postprocessing][strip] = [im_output, vips_output].map do |path|
        optimized = "#{path}.strip-#{strip}.jpg"
        FileUtils.cp(path, optimized)
        FileHelper.image_optim(strip_image_metadata: strip).optimize_image!(optimized)
        inspect_image(optimized)
      end
    end
  rescue StandardError => error
    record[:error] = "#{error.class}: #{error.message}"
  end
  record
end
report = { cmyk_profile: cmyk_profile, metadata_parity: "unassessed; postprocessing measures optimizer stage with explicit strip configuration", results: results }
File.write(root.join("results.json"), JSON.pretty_generate(report))
puts JSON.pretty_generate(report)

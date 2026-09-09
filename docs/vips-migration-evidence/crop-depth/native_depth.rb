require "vips"
require "json"
require "digest"

report = JSON.parse(File.read("crop-results.json"))
rows = report.fetch("samples").map do |sample|
  images = {}
  outputs = sample.fetch("outputs").to_h do |backend, output|
    path = output.fetch("path")
    image = Vips::Image.pngload(path)
    images[backend] = image
    [backend, { path:, sha256: Digest::SHA256.file(path).hexdigest, bytes: File.size(path), png_bit_depth: File.binread(path, 25).getbyte(24), png_color_type: File.binread(path, 26).getbyte(25), format: image.format, interpretation: image.interpretation, bands: image.bands, alpha: image.has_alpha?, dimensions: [image.width, image.height] }]
  end
  before, after = images.values_at("imagemagick", "libvips")
  difference = if before.format == after.format && before.bands == after.bands
    delta = (before.cast(:double) - after.cast(:double)).abs
    { mean: delta.avg, maximum: delta.max, units: before.format.to_s, hidden_rgb_included: true }
  else
    { comparable: false, reason: "Native sample formats or band counts differ" }
  end
  { name: sample.fetch("name"), outputs:, native_sample_difference: difference }
end
File.write("native-depth.json", JSON.pretty_generate({ process_uid: Process.uid, image_digest: ENV.fetch("BENCH_IMAGE_DIGEST"), samples: rows }) + "\n")

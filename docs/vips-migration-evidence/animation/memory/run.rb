require "json"
require "fileutils"
require "digest"
eval(File.read("/probe/bootstrap.rb"), TOPLEVEL_BINDING, "/work/boot.rb")
require "nokogiri" if ENV.fetch("OPERATION") == "svg-dimensions"
row = JSON.parse(File.read("/probe/cases.json")).fetch(Integer(ENV.fetch("CASE_INDEX")))
operation = row.fetch("operation")
backend = ENV.fetch("BACKEND").to_sym
input_path = Rails.root.join(row.fetch("input")).to_s
raise "input hash mismatch" unless Digest::SHA256.file(input_path).hexdigest == row.fetch("source_sha256")
output_directory = Pathname.new("/tmp/memory-output")
FileUtils.mkdir_p(output_directory)
input_format = File.extname(input_path).delete_prefix(".")
input_format = "jpeg" if input_format == "jpg"
source_quality = row["quality"]
suffix = %w[heif jpeg orientation].include?(operation) ? "jpg" : "png"
outputs = %i[imagemagick libvips].to_h { |name| [name, output_directory.join("output-#{name}.#{suffix}").to_s] }
Vips.cache_set_max(0)
Vips.concurrency_set(1)
Dir.chdir(File.dirname(input_path)) if operation == "og"
def run_transform(operation:, backend:, sample:, input_path:, output_path:, quality:)
  if backend == :imagemagick
    instructions = sample.fetch("instructions").map do |argument|
      case argument
      when "@INPUT@"
        "#{sample.fetch("input_format")}:#{input_path}[0]"
      when "@OUTPUT@"
        "#{sample.fetch("output_format")}:#{output_path}"
      when "@PROFILE@"
        Rails.root.join("vendor/data/RT_sRGB.icm").to_s
      else
        argument
      end
    end
    ImageMagick.magick(*instructions, operation: :"optimized_image_#{operation}", read: [input_path], write: [File.dirname(output_path)], timeout: 20, nice: 10)
  else
    arguments = { input_path:, output_path:, input_format: sample.fetch("input_format"), output_format: sample.fetch("output_format"), quality:, timeout: 20 }
    if operation == "downsize"
      DiscourseVips.downsize(**arguments, geometry: sample.fetch("geometry"))
    else
      arguments.merge!(width: sample.fetch("width"), height: sample.fetch("height"), strip_metadata: sample.fetch("strip_metadata"))
      if operation == "crop"
        DiscourseVips.crop(**arguments)
      else
        DiscourseVips.resize(**arguments)
      end
    end
  end
end


case operation
when "animation"
  operations = {
    imagemagick: -> {
      ImageMagick.identify(
        "-ping", "-format", "%n\\n", input_path,
        operation: :upload_animation_probe, read: [input_path], timeout: 5,
      ).to_i > 1
    },
    libvips: -> { DiscourseVips.animated?(input_path:, timeout: 5) },
  }
when "svg-dimensions"
  operations = {
    imagemagick: -> {
      ImageMagick.identify(
        "-ping", "-format", "%w,%h", "MSVG:#{input_path}",
        operation: :upload_svg_dimensions, read: [input_path], timeout: 5,
      ).strip.split(",").map { |value| Integer(value, 10) }
    },
    libvips: -> { DiscourseVips.svg_dimensions(input_path:, timeout: 5) },
  }
when "svg-assets"
  operations = {
    imagemagick: -> {
      ImageMagick.magick("MSVG:#{input_path}", outputs[:imagemagick], operation: :topic_og_asset_render, read: [input_path], write: [output_directory.to_s], timeout: 10)
    },
    libvips: -> { DiscourseVips.svg_to_png(input_path: input_path, output_path: outputs[:libvips], timeout: 10) },
  }
when "og"
  operations = {
    imagemagick: -> {
      ImageMagick.magick("-background", "none", "-size", "1200x630", "MSVG:#{input_path}", "-depth", "8", "-define", "png:compression-level=9", outputs[:imagemagick], operation: :topic_og_render, read: [File.dirname(input_path)], write: [output_directory.to_s], nice: 10, timeout: 20)
    },
    libvips: -> { DiscourseVips.topic_og_render(input_path: input_path, output_path: outputs[:libvips], timeout: 20) },
  }
when "heif"
  operations = {
    imagemagick: -> {
      ImageMagick.magick(input_path, "-auto-orient", "-background", "white", "-interlace", "none", "-flatten", outputs[:imagemagick], operation: :upload_format_conversion, read: [input_path], write: [output_directory.to_s], timeout: 20)
    },
    libvips: -> { DiscourseVips.heif_to_jpeg(input_path: input_path, output_path: outputs[:libvips], timeout: 20) },
  }
when "ico"
  operations = {
    imagemagick: -> {
      ImageMagick.magick("#{input_path}[-1]", "-auto-orient", "-background", "white", "-interlace", "none", outputs[:imagemagick], operation: :upload_format_conversion, read: [input_path], write: [output_directory.to_s], timeout: 20)
    },
    libvips: -> { DiscourseVips.ico_to_png(input_path: input_path, output_path: outputs[:libvips], timeout: 20) },
  }
when "jpeg"
  operations = {
    imagemagick: -> {
      ImageMagick.magick("#{input_format}:#{input_path}", "-auto-orient", "-background", "white", "-interlace", "none", "-flatten", "-quality", "75", "jpg:#{outputs[:imagemagick]}", operation: :upload_format_conversion, read: [input_path], write: [output_directory.to_s], timeout: 20)
    },
    libvips: -> { DiscourseVips.convert_to_jpeg(input_path: input_path, output_path: outputs[:libvips], input_format: input_format, quality: 75, timeout: 20) },
  }
when "orientation"
  operations = {
    imagemagick: -> {
      path = outputs.fetch(:imagemagick)
      ImageMagick.magick("jpeg:#{path}", "-auto-orient", "jpeg:#{path}", operation: :upload_auto_orient, read: [path], write: [path, output_directory.to_s], timeout: 5)
    },
    libvips: -> { DiscourseVips.auto_orient(input_path:, output_path: outputs.fetch(:libvips), source_quality:, timeout: 5) },
  }
when "downsize", "resize", "crop"
  sample = row.fetch("parameters")
  output_path = output_directory.join("output.#{sample.fetch('output_suffix')}").to_s
  operations = { backend => -> { run_transform(operation:, backend:, sample:, input_path:, output_path:, quality: row["quality"]) } }
when "quality"
  sample = row.fetch("parameters")
  operations = {
    imagemagick: -> { ImageMagick.image_quality(input_path:, timeout: 5) },
    libvips: -> { DiscourseVips.image_quality(input_path:, input_format: sample.fetch("input_format"), timeout: 5) },
  }
end
outcomes = 6.times.map do
  FileUtils.cp(input_path, outputs.fetch(:imagemagick)) if operation == "orientation" && backend == :imagemagick
  begin
    operations.fetch(backend).call
    { status: "ok" }
  rescue StandardError => error
    { status: "error", error_class: error.class.name, message: error.message }
  end
end
peak_bytes = Integer(File.read("/sys/fs/cgroup/memory.peak"))
stat = File.read("/sys/fs/cgroup/memory.stat").lines.to_h { |line| key, value = line.split; [key, Integer(value)] }
puts JSON.generate({case_index: Integer(ENV.fetch("CASE_INDEX")), backend:, sample: row.fetch("sample"), operation:, uid: Process.uid, peak_bytes:, peak_mib: peak_bytes / 1048576.0, end_memory_stat: stat, outcomes:})

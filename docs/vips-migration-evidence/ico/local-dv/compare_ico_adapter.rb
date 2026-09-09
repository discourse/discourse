require "chunky_png"
require "json"
require "landlock"
require "tmpdir"
require "vips"
require_relative "../../lib/discourse_vips/ico_image"

evidence_directory = File.expand_path("public/discourse-task/ico")
references = JSON.parse(File.read(File.join(evidence_directory, "references.json")))
results = references.map do |reference|
  input_path = File.expand_path(reference.fetch("path"))
  output_path = File.join(evidence_directory, "#{File.basename(input_path, ".ico")}-libvips.png")
  result = Dir.mktmpdir do |scratch|
    Landlock.fork(
      read: ["/bin", "/lib", "/lib64", "/usr", "/etc/ld.so.cache", input_path].select { |path| File.exist?(path) },
      write: [scratch, evidence_directory],
      execute: [],
      timeout: 20,
      env: { "HOME" => scratch, "TMPDIR" => scratch, "XDG_CACHE_HOME" => scratch },
      unsetenv_others: true,
      seccomp_deny_network: true,
      on_unsupported: :run_without_landlock,
    ) do |stdout, _stderr|
      Vips.block_untrusted(true)
      Vips.block("VipsForeignLoad", true)
      Vips.block("VipsForeignLoadPng", false)
      DiscourseVips::IcoImage.load(input_path).autorot.pngsave(output_path)
      stdout.write("ok")
    end
  end
  if !result.success?
    next({ reference:, error: result.stderr, timed_out: result.timed_out? })
  end
  image = ChunkyPNG::Image.from_file(output_path)
  pixels = 2.times.flat_map do |row|
    3.times.map do |column|
      pixel = image[(column * 2 + 1) * image.width / 6, (row * 2 + 1) * image.height / 4]
      [ChunkyPNG::Color.r(pixel), ChunkyPNG::Color.g(pixel), ChunkyPNG::Color.b(pixel), ChunkyPNG::Color.a(pixel)]
    end
  end
  { reference:, actual: { width: image.width, height: image.height, pixels: } }
end
File.write(File.join(evidence_directory, "comparison.json"), JSON.pretty_generate(results))
puts JSON.generate(results)

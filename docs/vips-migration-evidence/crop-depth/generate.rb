require "vips"
require "json"
require "digest"
require "fileutils"

FileUtils.mkdir_p("inputs")
manifest = JSON.parse(File.read("manifest.json"))
manifest["inputs"] = {}
manifest["cases"] = []
{ "rgb16" => [:rgb16, 3], "rgba16" => [:rgb16, 4], "grey16" => [:grey16, 1], "greya16" => [:grey16, 2] }.each_with_index do |(name, (interpretation, bands)), index|
  values = Random.new(123 + index).bytes(768 * 512 * bands * 2).unpack("S<*")
  if [2, 4].include?(bands)
    [1, 255, 256, 32_768, 65_535].each_with_index { |alpha, pixel| values[pixel * bands + bands - 1] = alpha }
  end
  path = "inputs/#{name}.png"
  Vips::Image.new_from_memory(values.pack("S*"), 768, 512, bands, :ushort).copy(interpretation:).pngsave(path, bitdepth: 16)
  manifest["inputs"][path] = { "sha256" => Digest::SHA256.file(path).hexdigest, "bytes" => File.size(path), "origin" => "generate.rb: seeded genuine 16-bit samples, seed #{123 + index}" }
  [false, true].each do |strip|
    manifest["cases"] << {
      "operation" => "crop", "name" => "#{name}-strip-#{strip}", "input" => path,
      "input_format" => "png", "output_format" => "png", "output_suffix" => "png",
      "strip_metadata" => strip, "quality" => nil, "width" => 640, "height" => 480,
      "expected_dimensions" => [640, 480], "historical_baseline" => false,
      "instructions" => ["@INPUT@", "-auto-orient", "-gravity", "north", "-background", "transparent", strip ? "-thumbnail" : "-resize", "640x480^", "-crop", "640x480+0+0", "-unsharp", "2x0.5+0.7+0", "-interlace", "none", "-profile", "@PROFILE@", "@OUTPUT@"]
    }
  end
end
manifest["fixture_generator_sha256"] = Digest::SHA256.file(__FILE__).hexdigest
File.write("manifest.json", JSON.pretty_generate(manifest) + "\n")

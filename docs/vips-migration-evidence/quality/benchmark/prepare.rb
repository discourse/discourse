manifest = JSON.parse(File.read(Rails.root.join("source-manifest.json")))
corpus_path = Rails.root.join("corpus.json")
generated = Rails.root.join("generated")
raise "Preserve existing preparation output" if corpus_path.exist? || generated.exist?
FileUtils.mkdir_p(generated)
samples = manifest.fetch("inputs").dup
source = Rails.root.join(samples.find { |sample| sample.fetch("name") == "jpeg-matrix-source" }.fetch("path")).to_s
default_path = generated.join("jpeg-default.jpg").to_s
ImageMagick.magick(source, "-interlace", "none", default_path, operation: :benchmark_fixture_generation, read: [source], write: [generated.to_s], timeout: 20)

custom_path = generated.join("jpeg-custom-table.jpg").to_s
contents = File.binread(default_path)
raise "Expected JPEG SOI" unless contents.start_with?("\xFF\xD8".b)
offset = 2
mutation = nil
while offset + 4 <= contents.bytesize
  raise "Invalid JPEG marker" unless contents.getbyte(offset) == 255
  marker = contents.getbyte(offset + 1)
  break if marker == 218 || marker == 217
  length = contents.byteslice(offset + 2, 2).unpack1("n")
  raise "Invalid JPEG segment" if length < 2 || offset + 2 + length > contents.bytesize
  if marker == 219 && length >= 67 && contents.getbyte(offset + 4) >> 4 == 0
    coefficient_offset = offset + 68
    previous = contents.getbyte(coefficient_offset)
    replacement = previous % 255 + 1
    contents.setbyte(coefficient_offset, replacement)
    mutation = { offset: coefficient_offset, previous:, replacement: }
    break
  end
  offset += length + 2
end
raise "No eight-bit quantization table found" unless mutation
File.binwrite(custom_path, contents)
jpegli_path = generated.join("jpegli-quality-75.jpg").to_s
Vips::Image.jpegload(source).jpegsave(jpegli_path, Q: 75)

[
  ["jpeg-default", default_path, { encoder: "ImageMagick", arguments: ["-interlace", "none"], quality_override: nil }],
  ["jpeg-custom-table", custom_path, { source: "jpeg-default", quantization_coefficient_mutation: mutation }],
  ["jpegli-quality-75", jpegli_path, { encoder: "ruby-vips jpegsave", arguments: { Q: 75 } }],
].each do |name, path, recipe|
  samples << { "name" => name, "input_format" => "jpeg", "path" => Pathname.new(path).relative_path_from(Rails.root).to_s, "sha256" => Digest::SHA256.file(path).hexdigest, "bytes" => File.size(path), "recipe" => recipe }
end
File.write(corpus_path, JSON.pretty_generate({ provenance: quality_provenance("prepare"), generation_timed: false, samples: }) + "\n")
puts JSON.generate({ samples: samples.length, corpus: corpus_path.to_s })

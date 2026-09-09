manifest = JSON.parse(File.read(Rails.root.join("source-manifest.json")))
source_record = manifest.fetch("inputs").find { |sample| sample.fetch("name") == "jpeg-matrix-source" }
source = Rails.root.join(source_record.fetch("path")).to_s
directory = Rails.root.join("matrix")
result_path = ENV.fetch("RESULT_PATH", Rails.root.join("matrix-results.json").to_s)
raise "Preserve existing matrix output" if directory.exist? || File.exist?(result_path)
FileUtils.mkdir_p(directory)
report = { provenance: quality_provenance("matrix"), timed: false, expected_checks: 500, input: source_record, checks: [], comparison: "Compare actual public helper values, not the requested encoder quality. Four ImageMagick families and ruby-vips jpegsave follow reference/check_jpeg_quality.rb." }
recipes = [false, true].product([false, true]).flat_map do |grayscale, progressive|
  (1..100).map { |quality| { encoder: "imagemagick", quality:, grayscale:, progressive: } }
end
recipes.concat((1..100).map { |quality| { encoder: "ruby-vips jpegsave", quality: } })
image = Vips::Image.jpegload(source)
recipes.each_with_index do |recipe, index|
  relative = "matrix/#{format('%03d', index + 1)}.jpg"
  path = Rails.root.join(relative).to_s
  record = { recipe:, path: relative }
  begin
    if recipe[:encoder] == "imagemagick"
      ImageMagick.magick(source, "-colorspace", recipe[:grayscale] ? "gray" : "sRGB", "-interlace", recipe[:progressive] ? "plane" : "none", "-quality", recipe[:quality].to_s, path, operation: :benchmark_fixture_generation, read: [source], write: [directory.to_s], timeout: 20)
    else
      image.jpegsave(path, Q: recipe[:quality])
    end
    sample = { "path" => relative, "input_format" => "jpeg" }
    record[:sha256] = Digest::SHA256.file(path).hexdigest
    record[:bytes] = File.size(path)
    record[:imagemagick] = quality_outcome(backend: :imagemagick, sample:)
    record[:libvips] = quality_outcome(backend: :libvips, sample:)
    record[:compatible] = record[:imagemagick][:status] == "ok" && record[:libvips][:status] == "ok" && record[:imagemagick][:value] == record[:libvips][:value]
  rescue StandardError => error
    record[:compatible] = false
    record[:generation_error] = { class: error.class.name, message: error.message }
  end
  report[:checks] << record
  File.write(result_path, JSON.pretty_generate(report) + "\n")
end
report[:failures] = report[:checks].reject { |record| record[:compatible] }
report[:input_unchanged] = Digest::SHA256.file(source).hexdigest == source_record.fetch("sha256")
report[:compatible] = report[:checks].length == 500 && report[:failures].empty? && report[:input_unchanged]
File.write(result_path, JSON.pretty_generate(report) + "\n")
puts JSON.generate({ checks: report[:checks].length, failures: report[:failures].length, compatible: report[:compatible] })
DiscourseVips.before_fork
exit(report[:compatible] ? 0 : 1)

manifest = JSON.parse(File.read(Rails.root.join("source-manifest.json")))
manifest.fetch("files").merge(manifest.fetch("bundle_files")).each do |path, expected|
  raise "Snapshot changed: #{path}" unless Digest::SHA256.file(Rails.root.join(path)).hexdigest == expected
end
Vips.cache_set_max(0)
Vips.concurrency_set(1)
directory = Rails.root.join("outputs-white")
FileUtils.mkdir_p(directory)
FileUtils.mkdir_p(Rails.root.join("tmp"))
content = {
  "white-text" => '<style>.black { fill: #FFFFFF; }</style><text class="black" x="25" y="25">Discourse</text>',
  "opaque-red-region" => '<rect x="25" y="10" width="50" height="30" fill="red"/>',
  "half-alpha-red" => '<rect width="100" height="50" fill="red" opacity="0.5"/>',
  "empty" => '',
  "explicit-blue-background" => '<rect width="100" height="50" fill="blue"/><rect x="25" y="10" width="50" height="30" fill="red" opacity="0.5"/>',
}

def png_pixels(path)
  image = Vips::Image.pngload(path).colourspace(:srgb)
  rgba = image.has_alpha? ? image : image.bandjoin(255)
  alpha = rgba[3]
  samples = [[0, 0], [image.width / 4, image.height / 4], [image.width / 2, image.height / 2], [image.width * 3 / 4, image.height * 3 / 4], [image.width - 1, image.height - 1]]
  {
    dimensions: [image.width, image.height],
    bytes: File.size(path),
    sha256: Digest::SHA256.file(path).hexdigest,
    bands: image.bands,
    alpha: { min: alpha.min, max: alpha.max, mean: alpha.avg },
    rgba_samples: samples.map { |x, y| { x:, y:, rgba: rgba.getpoint(x, y) } },
    icc_sha256: image.get_typeof("icc-profile-data") != 0 ? Digest::SHA256.hexdigest(image.get("icc-profile-data")) : nil,
  }
end

def background_difference(first_path:, second_path:, background:)
  first = Vips::Image.pngload(first_path).colourspace(:srgb)
  second = Vips::Image.pngload(second_path).colourspace(:srgb)
  raise "Dimensions differ" unless [first.width, first.height] == [second.width, second.height]
  first = first.flatten(background:) if first.has_alpha?
  second = second.flatten(background:) if second.has_alpha?
  stats = (first - second).abs.stats
  { mean: stats.getpoint(4, 0).first, max: stats.getpoint(1, 0).first }
end

report = { source: manifest, boundary: "Exact geometry commands and native facade; no optimizer or timing; control changes only ImageMagick background before input", cases: [] }
[false, true].each do |namespace|
  content.each do |label, drawing|
    name = "#{namespace ? 'namespaced' : 'namespace-less'}-#{label}"
    input = directory.join("#{name}.svg").to_s
    File.write(input, "<svg#{namespace ? ' xmlns="http://www.w3.org/2000/svg"' : ''} width=\"100\" height=\"50\">#{drawing}</svg>")
    %w[resize crop downsize].each do |operation|
      modes = operation == "downsize" ? [false] : [false, true]
      modes.each do |strip|
        SiteSetting.strip_image_metadata = strip
        record = { name:, operation:, strip_metadata: strip, source_sha256: Digest::SHA256.file(input).hexdigest, backends: {} }
        completed = {}
        %w[imagemagick imagemagick-pre-input-transparent libvips].each do |backend|
          output = directory.join("#{name}-#{operation}-#{strip}-#{backend}.png").to_s
          begin
            if backend.start_with?("imagemagick")
              dimensions = operation == "downsize" ? "50%" : "30x20"
              instructions = OptimizedImage.public_send("#{operation}_instructions", input, output, dimensions, format: "png")
              instructions = ["-background", "none", *instructions] if backend == "imagemagick-pre-input-transparent"
              ImageMagick.magick(*instructions, operation: :"optimized_image_#{operation}", read: [input], write: [directory.to_s], nice: 10, timeout: 20)
              record[:backends][backend] = { instructions:, pixels: png_pixels(output) }
            else
              arguments = { input_path: input, output_path: output, input_format: "svg", output_format: "png", quality: nil, timeout: 20 }
              if operation == "downsize"
                arguments[:geometry] = "50%"
              else
                arguments.merge!(width: 30, height: 20, strip_metadata: strip)
              end
              DiscourseVips.public_send(operation, **arguments)
              record[:backends][backend] = { pixels: png_pixels(output) }
            end
            completed[backend] = output
          rescue StandardError => error
            record[:backends][backend] = { error: "#{error.class}: #{error.message}" }
          end
        end
        if completed.key?("imagemagick") && completed.key?("libvips")
          record[:visible_difference] = [0, 255].to_h do |level|
            [level, background_difference(first_path: completed.fetch("imagemagick"), second_path: completed.fetch("libvips"), background: [level, level, level])]
          end
        end
        report[:cases] << record
        File.write(Rails.root.join("results-white.json"), JSON.pretty_generate(report))
      end
    end
  end
end
puts JSON.pretty_generate(report)

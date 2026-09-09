require "vips"
require "json"
require "digest"

RSpec.describe OptimizedImage do
  describe ".crop" do
    it "records native depth after the real optimizer for both backends and metadata modes" do
      directory = Rails.root.join("public/discourse-task/crop-depth-caller")
      FileUtils.mkdir_p(directory)
      SiteSetting.composer_media_optimization_image_enabled = false
      results = []
      %w[rgb16 rgba16 grey16 greya16].each do |name|
        input = Rails.root.join("public/discourse-task/crop-depth-benchmark/inputs/#{name}.png").to_s
        [false, true].each do |strip|
          SiteSetting.strip_image_metadata = strip
          [false, true].each do |enabled|
            global_setting :enable_vips_image_processing, enabled
            output = directory.join("#{name}-strip-#{strip}-vips-#{enabled}.png").to_s

            result = described_class.crop(input, output, 640, 480, raise_on_error: true)

            image = Vips::Image.pngload(output)
            results << { name:, strip:, vips: enabled, result:, output: File.basename(output), bytes: File.size(output), sha256: Digest::SHA256.file(output).hexdigest, png_bit_depth: File.binread(output, 25).getbyte(24), format: image.format, bands: image.bands, alpha: image.has_alpha?, dimensions: [image.width, image.height] }
            expect(result).to eq(true)
            expect([image.width, image.height]).to eq([640, 480])
            expect(File.binread(output, 25).getbyte(24)).to be <= 8 if strip
          end
        end
      end
      File.write(directory.join("results.json"), JSON.pretty_generate(results) + "\n")
    end
  end
end

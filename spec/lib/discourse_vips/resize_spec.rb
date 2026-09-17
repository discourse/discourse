# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".resize" do
    let(:directory) { Dir.mktmpdir }
    let(:input_path) { File.join(directory, "source.png") }
    let(:output_path) { File.join(directory, "output.png") }

    before { FileUtils.cp(file_from_fixtures("logo.png").path, input_path) }

    after { FileUtils.remove_entry(directory) }

    def resize(**options)
      described_class.resize(
        input_path: input_path,
        output_path: output_path,
        input_format: "png",
        output_format: "png",
        width: 100,
        height: 50,
        timeout: 10,
        read: [input_path],
        write: [directory],
        **options,
      )
    end

    it "resizes an image in place" do
      resize(output_path: input_path)

      expect(FastImage.size(input_path)).to eq([100, 50])
    end

    it "rejects unsupported output formats" do
      expect { resize(output_format: "svg") }.to raise_error(ArgumentError, "unsupported format")
    end

    it "reports invalid dimensions as an operation error" do
      expect { resize(width: 0) }.to raise_error(DiscourseVips::Error, "invalid resize dimensions")
    end

    it "preserves the destination and removes temporary files after a decode error" do
      File.binwrite(input_path, "invalid image")
      File.binwrite(output_path, "existing destination")

      expect { resize }.to raise_error(DiscourseVips::InvalidImage)

      expect(File.binread(output_path)).to eq("existing destination")
      expect(Dir.children(directory)).to contain_exactly("source.png", "output.png")
    end

    it "rejects an SVG disguised as a PNG" do
      FileUtils.cp(file_from_fixtures("svg.png").path, input_path)

      expect { resize }.to raise_error(DiscourseVips::InvalidImage)
    end
  end
end

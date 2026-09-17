# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".downsize" do
    let(:directory) { Dir.mktmpdir }
    let(:input_path) { File.join(directory, "source.png") }
    let(:output_path) { File.join(directory, "output.png") }

    after { FileUtils.remove_entry(directory) }

    it "scales an image by the requested factor" do
      FileUtils.cp(file_from_fixtures("logo.png").path, input_path)
      output_path = File.join(directory, "output")

      described_class.downsize(
        input_path:,
        output_path:,
        scale: 0.5,
        timeout: 20,
        read: [input_path],
        write: [directory],
      )

      expect(FastImage.size(output_path)).to eq([122, 33])
      expect(FastImage.type(output_path)).to eq(:png)
    end

    it "rejects an image disguised as another format" do
      input_path = file_from_fixtures("svg.png").path

      expect {
        described_class.downsize(
          input_path:,
          output_path:,
          scale: 0.5,
          timeout: 20,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::InvalidImage)

      expect(File).not_to exist(output_path)
    end

    it "rejects an unsupported format" do
      input_path = File.join(directory, "source.ico")

      expect {
        described_class.downsize(
          input_path:,
          output_path:,
          scale: 0.5,
          timeout: 20,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(ArgumentError, "unsupported format")
    end

    it "rejects conflicting resize targets" do
      input_path = file_from_fixtures("logo.png").path

      expect {
        described_class.downsize(
          input_path:,
          output_path:,
          scale: 0.5,
          width: 100,
          height: 100,
          timeout: 20,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(
        ArgumentError,
        "provide exactly one resize target: scale, width and height, or max_pixels",
      )
    end

    it "reports invalid bounds as an operation error" do
      FileUtils.cp(file_from_fixtures("logo.png").path, input_path)

      expect {
        described_class.downsize(
          input_path:,
          output_path:,
          width: 0,
          height: 100,
          timeout: 20,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::Error, "invalid resize bounds")
    end

    it "reports an invalid scale as an operation error" do
      FileUtils.cp(file_from_fixtures("logo.png").path, input_path)

      expect {
        described_class.downsize(
          input_path:,
          output_path:,
          scale: 0,
          timeout: 20,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::Error, "invalid resize scale")
    end

    it "preserves the destination and removes temporary files when decoding fails" do
      File.binwrite(input_path, "invalid image")
      original_content = "original destination"
      File.binwrite(output_path, original_content)

      expect {
        described_class.downsize(
          input_path:,
          output_path:,
          scale: 0.5,
          timeout: 20,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::InvalidImage)

      expect(File.binread(output_path)).to eq(original_content)
      expect(Dir.children(directory)).to contain_exactly(
        File.basename(input_path),
        File.basename(output_path),
      )
    end
  end
end

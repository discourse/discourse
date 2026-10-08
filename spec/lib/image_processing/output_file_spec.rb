# frozen_string_literal: true

require "image_processing/output_file"

RSpec.describe ImageProcessing::OutputFile do
  describe ".write" do
    let(:destination) { Tempfile.new(%w[destination .png], binmode: true) }
    let(:image_contents) { File.binread(file_from_fixtures("logo.png").path) }

    before do
      destination.write("original")
      destination.flush
    end

    after { destination.close! }

    it "makes successful output available through the open destination file" do
      described_class.write(destination.path) { |path| File.binwrite(path, image_contents) }

      destination.rewind
      expect(destination.read).to eq(image_contents)
    end

    it "preserves the destination contents when processing fails" do
      expect {
        described_class.write(destination.path) do |path|
          File.binwrite(path, "partial")
          raise "rendering failed"
        end
      }.to raise_error(RuntimeError, "rendering failed")

      expect(File.binread(destination.path)).to eq("original")
    end
  end
end

# frozen_string_literal: true

require "discourse_vips/jpeg_quality"

RSpec.describe DiscourseVips::JpegQuality do
  describe ".estimate" do
    { "exif_orientation.jpg" => 95, "logo.jpg" => 94, "huge.jpg" => 80 }.each do |filename, quality|
      it "estimates the quantization quality of #{filename}" do
        result = described_class.estimate(file_from_fixtures(filename).path)

        expect(result).to eq(quality)
      end
    end

    it "rejects a file without a JPEG header" do
      expect { described_class.estimate(file_from_fixtures("fake.jpg").path) }.to raise_error(
        ArgumentError,
        "invalid JPEG header",
      )
    end

    it "rejects a truncated quantization table" do
      Tempfile.create(%w[truncated .jpg]) do |file|
        file.binmode
        file.write("\xFF\xD8\xFF\xDB\x00\x43\x00".b)
        file.flush

        expect { described_class.estimate(file.path) }.to raise_error(
          ArgumentError,
          "invalid JPEG segment length",
        )
      end
    end

    it "reads 16-bit tables and uses the latest table definition regardless of order" do
      tables =
        [0, *Array.new(64, 255)].pack("C*") + [0x11].pack("C") + Array.new(64, 1).pack("n*") +
          [0x10].pack("C") + Array.new(64, 1).pack("n*")
      bytes = "\xFF\xD8\xFF\xDB".b + [tables.bytesize + 2].pack("n") + tables + "\xFF\xDA".b

      Tempfile.create(%w[quantization .jpg]) do |file|
        file.binmode
        file.write(bytes)
        file.flush

        expect(described_class.estimate(file.path)).to eq(100)
      end
    end

    it "rejects invalid table identifiers and precisions" do
      [0x04, 0x20].each do |definition|
        bytes = "\xFF\xD8\xFF\xDB\x00\x43".b + [definition, *Array.new(64, 1)].pack("C*")
        Tempfile.create(%w[invalid-table .jpg]) do |file|
          file.binmode
          file.write(bytes)
          file.flush

          expect { described_class.estimate(file.path) }.to raise_error(
            ArgumentError,
            "invalid JPEG quantization table",
          )
        end
      end
    end

    it "recognizes both lossless JPEG frame markers" do
      [0xC3, 0xCB].each do |marker|
        Tempfile.create(%w[lossless .jpg]) do |file|
          file.binmode
          file.write([0xFF, 0xD8, 0xFF, marker, 0, 2, 0xFF, 0xDA].pack("C*"))
          file.flush

          expect(described_class.estimate(file.path)).to eq(100)
        end
      end
    end
  end
end

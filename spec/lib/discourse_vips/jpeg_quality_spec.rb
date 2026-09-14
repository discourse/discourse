# frozen_string_literal: true

require "discourse_vips/jpeg_quality"

RSpec.describe DiscourseVips::JpegQuality do
  describe ".estimate" do
    it "identifies a standard JPEG quantization quality" do
      result = described_class.estimate(file_from_fixtures("exif_orientation.jpg").path)

      expect(result.status).to eq(:exact)
      expect(result.quality).to eq(95)
    end

    it "reports unknown for custom quantization tables outside its approximation range" do
      result = described_class.estimate(file_from_fixtures("logo.jpg").path)

      expect(result.status).to eq(:unknown)
      expect(result.quality).to eq(nil)
    end

    it "approximates a table close to standard JPEG quantization" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      coefficient_offset = original.index("\xFF\xDB".b) + 5
      original.setbyte(coefficient_offset, original.getbyte(coefficient_offset) + 1)

      result = described_class.estimate(StringIO.new(original))

      expect(result.status).to eq(:approximate)
      expect(result.quality).to eq(95)
    end

    it "rejects non-JPEG input" do
      expect { described_class.estimate(file_from_fixtures("logo.png").path) }.to raise_error(
        described_class::InvalidJPEG,
      )
    end

    it "rejects truncated JPEG headers" do
      expect { described_class.estimate(StringIO.new("\xFF\xD8".b)) }.to raise_error(
        described_class::InvalidJPEG,
      )
    end

    it "skips large metadata before estimating JPEG quality" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      metadata = [0xFF, 0xEF, 60_002].pack("CCn") + "x" * 60_000
      input = StringIO.new(original.byteslice(0, 2) + metadata * 8 + original.byteslice(2..))

      expect(described_class.estimate(input).quality).to eq(95)
    end

    it "accepts marker fill bytes" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      input = StringIO.new(original.byteslice(0, 2) + "\xFF".b + original.byteslice(2..))

      expect(described_class.estimate(input).quality).to eq(95)
    end

    it "rejects a segment length shorter than its length field" do
      input = StringIO.new([0xFF, 0xD8, 0xFF, 0xDB, 0, 1].pack("C*"))

      expect { described_class.estimate(input) }.to raise_error(described_class::InvalidJPEG)
    end
  end
end

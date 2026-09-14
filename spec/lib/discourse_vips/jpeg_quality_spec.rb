# frozen_string_literal: true

require "discourse_vips/jpeg_quality"

RSpec.describe DiscourseVips::JpegQuality do
  def jpeg_header(tables:, table_ids: [0], frame_marker: 0xC0)
    frame =
      [8, 1, 1, table_ids.length].pack("CnnC") +
        table_ids.each_with_index.map { |id, index| [index + 1, 0x11, id].pack("C3") }.join
    scan =
      [table_ids.length].pack("C") +
        table_ids.each_index.map { |index| [index + 1, 0].pack("C2") }.join + [0, 63, 0].pack("C3")
    "\xFF\xD8\xFF\xDB".b + [tables.bytesize + 2].pack("n") + tables +
      [0xFF, frame_marker, frame.bytesize + 2].pack("CCn") + frame + "\xFF\xDA".b +
      [scan.bytesize + 2].pack("n") + scan
  end

  describe ".estimate" do
    it "identifies quality 100 from a 16-bit quantization table" do
      input = jpeg_header(tables: [0x10].pack("C") + Array.new(64, 1).pack("n*"))

      result = described_class.estimate(StringIO.new(input))

      expect(result.quality).to eq(100)
      expect(result.precisions).to eq([16])
    end

    it "identifies the lowest baseline quality" do
      input = jpeg_header(tables: [0].pack("C") + Array.new(64, 255).pack("C*"))

      expect(described_class.estimate(StringIO.new(input)).quality).to eq(1)
    end

    it "reports every quantization table referenced by the frame" do
      table = Array.new(64, 1).pack("C*")
      input = jpeg_header(tables: "\x00".b + table + "\x01".b + table, table_ids: [0, 1, 1])

      result = described_class.estimate(StringIO.new(input))

      expect(result.quality).to eq(100)
      expect(result.table_count).to eq(2)
    end

    it "reports unknown when a referenced quantization table is missing" do
      input = jpeg_header(tables: "\x00".b + Array.new(64, 1).pack("C*"), table_ids: [0, 1, 1])

      expect(described_class.estimate(StringIO.new(input)).status).to eq(:unknown)
    end

    it "reports unknown for lossless JPEG frames" do
      input = jpeg_header(tables: "\x00".b + Array.new(64, 1).pack("C*"), frame_marker: 0xC3)

      expect(described_class.estimate(StringIO.new(input)).status).to eq(:unknown)
    end

    it "rejects a repeated frame header before the first scan" do
      original = jpeg_header(tables: "\x00".b + Array.new(64, 1).pack("C*"))
      frame_offset = original.index("\xFF\xC0".b)
      scan_offset = original.index("\xFF\xDA".b)
      frame = original.byteslice(frame_offset...scan_offset)
      input =
        StringIO.new(
          original.byteslice(0...scan_offset) + frame + original.byteslice(scan_offset..),
        )

      expect { described_class.estimate(input) }.to raise_error(
        described_class::InvalidJPEG,
        /multiple frame headers/,
      )
    end

    it "rejects JPEG headers larger than the maximum allowed size" do
      input = StringIO.new(jpeg_header(tables: "\x00".b + Array.new(64, 1).pack("C*")))

      stub_const(described_class::Parser, :MAX_HEADER_BYTES, 32) do
        expect { described_class.estimate(input) }.to raise_error(
          described_class::InvalidJPEG,
          /size limit/,
        )
      end
    end

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
      coefficient_offset = original.index("\xFF\xDB".b) + 5 + 63
      original.setbyte(coefficient_offset, original.getbyte(coefficient_offset) + 1)

      result = described_class.estimate(StringIO.new(original))

      expect(result.status).to eq(:approximate)
      expect(result.quality).to eq(95)
    end

    it "reports unknown when luminance quantization is also used for chroma" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      frame_offset = original.index("\xFF\xC0".b)
      original.setbyte(frame_offset + 15, 0)
      original.setbyte(frame_offset + 18, 0)

      expect(described_class.estimate(StringIO.new(original)).status).to eq(:unknown)
    end

    it "reports unknown when one coefficient is far from standard quantization" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      coefficient_offset = original.index("\xFF\xDB".b) + 5
      original.setbyte(coefficient_offset, original.getbyte(coefficient_offset) * 4)

      expect(described_class.estimate(StringIO.new(original)).status).to eq(:unknown)
    end

    it "reports unknown when component identifiers do not establish luminance and chroma roles" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      frame_offset = original.index("\xFF\xC0".b)
      original.setbyte(frame_offset + 10, 82)
      original.setbyte(frame_offset + 13, 71)
      original.setbyte(frame_offset + 16, 66)

      expect(described_class.estimate(StringIO.new(original)).status).to eq(:unknown)
    end

    it "reports unknown when the Adobe marker identifies RGB components" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      adobe = "Adobe" + [100, 0, 0, 0].pack("nnnC")
      marker = [0xFF, 0xEE, adobe.bytesize + 2].pack("CCn") + adobe
      input = StringIO.new(original.byteslice(0, 2) + marker + original.byteslice(2..))

      expect(described_class.estimate(input).status).to eq(:unknown)
    end

    it "estimates quality when a short APP14 marker is not an Adobe header" do
      original = File.binread(file_from_fixtures("exif_orientation.jpg").path)
      marker = [0xFF, 0xEE, 7].pack("CCn") + "Adobe"
      input = StringIO.new(original.byteslice(0, 2) + marker + original.byteslice(2..))

      expect(described_class.estimate(input).quality).to eq(95)
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

    it "estimates quality when the JPEG contains large metadata segments" do
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

    it "rejects a segment whose declared length is less than two bytes" do
      input = StringIO.new([0xFF, 0xD8, 0xFF, 0xDB, 0, 1].pack("C*"))

      expect { described_class.estimate(input) }.to raise_error(described_class::InvalidJPEG)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Vips do
  def ico(entries:)
    offset = 6 + (entries.length * 16)
    directory = +""
    payload = +""

    entries.each do |entry|
      width = entry.fetch(:width)
      height = entry.fetch(:height)
      bytes = entry.fetch(:bytes)
      directory << [
        width == 256 ? 0 : width,
        height == 256 ? 0 : height,
        entry.fetch(:colors, 0),
        0,
        1,
        entry.fetch(:bits, 32),
        bytes.bytesize,
        offset,
      ].pack("C4v2V2")
      payload << bytes
      offset += bytes.bytesize
    end

    [0, 1, entries.length].pack("v3") + directory + payload
  end

  def indexed_dib
    header = [40, 2, 2, 1, 1, 0, 4, 0, 0, 2, 0].pack("Vl<2v2V6")
    palette = [0, 0, 0, 0, 0, 0, 255, 0].pack("C8")
    pixels = [0x80, 0, 0, 0].pack("C4")
    mask = [0x40, 0, 0, 0].pack("C4")
    header + palette + pixels + mask
  end

  describe ".ico_to_png" do
    it "decodes the existing true-color DIB fixture" do
      Dir.mktmpdir("vips-ico") do |directory|
        output = File.join(directory, "output.png")

        described_class.ico_to_png(
          path: Rails.root.join("spec/fixtures/images/smallest.ico").to_s,
          output:,
        )

        image = ChunkyPNG::Image.from_file(output)
        expect({ dimensions: [image.width, image.height], pixel: image[0, 0] }).to eq(
          { dimensions: [1, 1], pixel: ChunkyPNG::Color.rgba(255, 0, 0, 255) },
        )
      end
    end

    it "selects the final embedded PNG entry" do
      Dir.mktmpdir("vips-ico") do |directory|
        first = ChunkyPNG::Image.new(1, 1, ChunkyPNG::Color.rgb(255, 0, 0)).to_blob
        second = ChunkyPNG::Image.new(2, 3, ChunkyPNG::Color.rgba(0, 255, 0, 127)).to_blob
        input = File.join(directory, "input.ico")
        output = File.join(directory, "output.png")
        File.binwrite(
          input,
          ico(
            entries: [
              { width: 1, height: 1, bytes: first },
              { width: 2, height: 3, bytes: second },
            ],
          ),
        )

        described_class.ico_to_png(path: input, output:)

        image = ChunkyPNG::Image.from_file(output)
        expect({ dimensions: [image.width, image.height], pixel: image[0, 0] }).to eq(
          { dimensions: [2, 3], pixel: ChunkyPNG::Color.rgba(0, 255, 0, 127) },
        )
      end
    end

    it "decodes indexed pixels and the transparency mask" do
      Dir.mktmpdir("vips-ico") do |directory|
        input = File.join(directory, "input.ico")
        output = File.join(directory, "output.png")
        File.binwrite(
          input,
          ico(entries: [{ width: 2, height: 1, colors: 2, bits: 1, bytes: indexed_dib }]),
        )

        described_class.ico_to_png(path: input, output:)

        image = ChunkyPNG::Image.from_file(output)
        expect([image[0, 0], image[1, 0]]).to eq(
          [ChunkyPNG::Color.rgba(255, 0, 0, 255), ChunkyPNG::Color.rgba(0, 0, 0, 0)],
        )
      end
    end

    it "rejects malformed and truncated containers without output" do
      Dir.mktmpdir("vips-ico") do |directory|
        output = File.join(directory, "output.png")
        malformed = File.join(directory, "malformed.ico")
        truncated = File.join(directory, "truncated.ico")
        File.binwrite(malformed, "not an icon")
        File.binwrite(truncated, [0, 1, 1].pack("v3") + [1, 1, 0, 0, 1, 32, 100, 22].pack("C4v2V2"))

        expect do described_class.ico_to_png(path: malformed, output:) end.to raise_error(
          Discourse::InvalidAccess,
        )
        expect do described_class.ico_to_png(path: truncated, output:) end.to raise_error(
          Discourse::InvalidAccess,
        )
        expect(File.exist?(output)).to eq(false)
      end
    end
  end
end

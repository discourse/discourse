# frozen_string_literal: true

RSpec.describe Vips do
  describe ".run" do
    it "processes an image with the stock CLI" do
      Dir.mktmpdir("vips-spec") do |directory|
        input = file_from_fixtures("logo.png").path
        output = File.join(directory, "copy.png")

        described_class.run("vips", "copy", input, output, read: [input], write: [directory])

        expect(FastImage.size(output)).to eq(FastImage.size(input))
      end
    end

    it "uses an untrusted loader only with explicit permission" do
      Dir.mktmpdir("vips-spec") do |directory|
        input = File.join(directory, "input.svg")
        output = File.join(directory, "output.png")
        File.write(
          input,
          '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="3"><rect width="2" height="3" fill="red"/></svg>',
        )

        expect {
          described_class.run("vips", "copy", input, output, read: [input], write: [directory])
        }.to raise_error(Discourse::Utils::CommandError)

        described_class.run(
          "vips",
          "copy",
          input,
          output,
          read: [input],
          write: [directory],
          allow_untrusted: true,
        )

        expect(FastImage.size(output)).to eq([2, 3])
      end
    end

    it "reads an image header field" do
      input = file_from_fixtures("logo.png").path

      format = described_class.run("vipsheader", "--field", "format", input, read: [input])

      expect(format).to include("VIPS_FORMAT_UCHAR")
    end
  end
end

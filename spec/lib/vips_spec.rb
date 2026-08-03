# frozen_string_literal: true

RSpec.describe Vips do
  describe ".run" do
    it "rejects broad access to untrusted operations" do
      expect { Vips.run("vips", "copy", allow_untrusted: true) }.to raise_error(
        ArgumentError,
        "Only an explicit svgload operation may enable untrusted libvips operations",
      )
    end

    it "permits an explicit SVG load" do
      Dir.mktmpdir("vips-spec") do |directory|
        input = File.join(directory, "input.svg")
        output = File.join(directory, "output.png")
        File.write(
          input,
          '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="3"><rect width="2" height="3" fill="red"/></svg>',
        )

        Vips.run(
          "vips",
          "svgload",
          input,
          output,
          read: [input],
          write: [directory],
          allow_untrusted: true,
        )

        expect(FastImage.size(output)).to eq([2, 3])
      end
    end
  end
end

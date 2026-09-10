# frozen_string_literal: true

require "chunky_png"

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns the libvips version" do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe ".dominant_color" do
    def dominant_color(filename)
      described_class.dominant_color(input_path: file_from_fixtures(filename).path, timeout: 5)
    end

    it "ignores RGB values in fully transparent pixels" do
      expect(dominant_color("dominant-color-hidden-rgb.png")).to eq("FF0000")
    end

    it "weights partially transparent pixels by their alpha" do
      expect(dominant_color("dominant-color-semitransparent.png")).to eq("AA0055")
    end

    it "returns black for a fully transparent image" do
      expect(dominant_color("dominant-color-transparent.png")).to eq("000000")
    end

    it "preserves low nonzero alpha values in 16-bit images" do
      expect(dominant_color("dominant-color-low-alpha-16bit.png")).to eq("FF0000")
    end

    it "normalizes floating-point grayscale JXL color values" do
      expect(dominant_color("dominant-color-float.jxl")).to eq("808080")
    end
  end

  describe ".topic_og_render" do
    it "preserves the rendered size of short title text" do
      Dir.mktmpdir do |directory|
        rendered_titles =
          [false, true].map do |marked_title|
            input_path = File.join(directory, "title-#{marked_title}.svg")
            output_path = File.join(directory, "title-#{marked_title}.png")
            marker = marked_title ? 'class="topic-og-title"' : ""
            File.write(input_path, <<~SVG)
              <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
                <text #{marker} x="80" y="190" font-family="sans-serif" font-size="62" font-weight="700">Hello world</text>
              </svg>
            SVG

            described_class.topic_og_render(input_path:, output_path:, timeout: 5)

            ChunkyPNG::Image.from_file(output_path).crop(80, 100, 1040, 100).pixels
          end

        expect(rendered_titles.first.any? { |pixel| ChunkyPNG::Color.a(pixel).positive? }).to eq(
          true,
        )
        expect(rendered_titles.last).to eq(rendered_titles.first)
      end
    end

    it "renders adjacent image assets on an 8-bit transparent canvas" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "og.svg")
        output_path = File.join(directory, "og.png")
        asset_path = File.join(directory, "logo.png")
        ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color.rgb(255, 0, 0)).save(asset_path)
        File.write(input_path, <<~SVG)
          <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
            <image href="#{asset_path}" width="100" height="100"/>
          </svg>
        SVG

        described_class.topic_og_render(input_path:, output_path:, timeout: 5)

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([1200, 630])
        expect(File.binread(output_path).getbyte(24)).to eq(8)
        expect(png[50, 50]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
        expect(ChunkyPNG::Color.a(png[200, 200])).to eq(0)
      end
    end

    it "rejects malformed SVGs" do
      file = file_from_contents('<svg width="1200" height="630">', "invalid.svg")

      Dir.mktmpdir do |directory|
        expect {
          described_class.topic_og_render(
            input_path: file.path,
            output_path: File.join(directory, "output.png"),
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
      end
    end

    it "preserves the SVG when the output points to the input file" do
      svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630"/>'

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "input.svg")
        output_path = File.join(directory, "output.png")
        File.write(input_path, svg)
        File.link(input_path, output_path)

        expect {
          described_class.topic_og_render(input_path:, output_path:, timeout: 5)
        }.to raise_error(DiscourseVips::Error, "SVG input and PNG output must be different files")
        expect(File.read(input_path)).to eq(svg)
      end
    end
  end

  describe "worker lifecycle" do
    it "recovers after the worker exits unexpectedly" do
      described_class.version
      worker_pid =
        Integer(
          IO.popen(["pgrep", "-P", Process.pid.to_s, "-f", "discourse vips worker"]) do |process|
            process.read
          end,
          10,
        )

      Process.kill("KILL", worker_pid)
      Process.waitpid(worker_pid)

      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "recovers after an operation times out" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "blocked.png")
        File.mkfifo(input_path)

        File.open(input_path, File::RDWR) do
          expect { described_class.dominant_color(input_path:, timeout: 0.05) }.to raise_error(
            DiscourseVips::OperationTimeout,
            "libvips operation timed out",
          )
        end
      end

      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "times out when the worker sends an incomplete response" do
      Dir.mktmpdir do |directory|
        socket_path = File.join(directory, "socket")
        server = UNIXServer.new(socket_path)
        server_thread =
          Thread.new do
            connection = server.accept
            connection.read
            connection.write("\x81")
            sleep 3
          ensure
            connection&.close
          end

        DiscourseVips::Client.stubs(:worker_socket_path).returns(socket_path)

        expect {
          described_class.dominant_color(input_path: "unused", timeout: 0.01)
        }.to raise_error(DiscourseVips::WorkerUnavailable, "libvips worker did not respond")
      ensure
        server&.close
        server_thread&.kill
        server_thread&.join
      end
    end
  end

  it "records image-processing instrumentation" do
    SiteSetting.instrument_image_processing = true
    input_path = file_from_fixtures("cropped.png").path

    events =
      DiscourseEvent.track_events(:image_processing_finished) do
        described_class.dominant_color(input_path:, timeout: 5)
      end

    expect(events.first[:params].first.except(:duration_seconds)).to eq(
      operation: "upload_dominant_color",
      success: true,
    )
  end
end

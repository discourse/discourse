# frozen_string_literal: true

RSpec.describe DiscourseVips, :with_vips_broker do
  describe ".start" do
    it "starts one broker and returns after it is ready" do
      socket_path = Rails.root.join("tmp", "discourse-vips-start-#{Process.pid}.sock").to_s
      described_class.stubs(socket_path:)

      broker_pid = described_class.start

      expect(described_class.start).to eq(broker_pid)
      expect(described_class.version).to match(/\A1-8\.\d+\.\d+\z/)
    ensure
      begin
        Process.kill("TERM", broker_pid) if broker_pid
      rescue Errno::ESRCH
      end
      FileUtils.rm_f(socket_path) if socket_path
      FileUtils.rm_f("#{socket_path}.lock") if socket_path
    end
  end

  describe ".version" do
    it "returns the interface and libvips versions" do
      expect(described_class.version).to match(/\A1-8\.\d+\.\d+\z/)
    end

    it "fails closed without Landlock outside local environments" do
      Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("production"))
      Discourse::SafeExec.stubs(landlock_supported?: false)

      expect { described_class.version }.to raise_error(
        DiscourseVips::Error,
        "Cannot run libvips because Landlock sandboxing is unavailable",
      )
    end

    it "starts one broker for concurrent requests when none is running" do
      socket_path = Rails.root.join("tmp", "discourse-vips-lazy-#{Process.pid}.sock").to_s
      described_class.stubs(socket_path:)

      versions = Array.new(4) { Thread.new { described_class.version } }.map(&:value)
      broker_pid = described_class.start

      expect(versions).to all(match(/\A1-8\.\d+\.\d+\z/))
    ensure
      begin
        Process.kill("TERM", broker_pid) if broker_pid
      rescue Errno::ESRCH
      end
      FileUtils.rm_f(socket_path) if socket_path
      FileUtils.rm_f("#{socket_path}.lock") if socket_path
    end

    it "replaces a broker that stops" do
      socket_path = Rails.root.join("tmp", "discourse-vips-restart-#{Process.pid}.sock").to_s
      described_class.stubs(socket_path:)
      previous_broker_pid = described_class.start
      Process.kill("KILL", previous_broker_pid)

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        begin
          Process.kill(0, previous_broker_pid)
        rescue Errno::ESRCH
          break
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise "libvips broker did not stop"
        end

        sleep 0.01
      end

      version = described_class.version
      replacement_broker_pid = described_class.start

      expect(version).to match(/\A1-8\.\d+\.\d+\z/)
      expect(replacement_broker_pid).not_to eq(previous_broker_pid)
    ensure
      begin
        Process.kill("TERM", replacement_broker_pid) if replacement_broker_pid
      rescue Errno::ESRCH
      end
      FileUtils.rm_f(socket_path) if socket_path
      FileUtils.rm_f("#{socket_path}.lock") if socket_path
    end
  end

  describe ".generate_letter_avatar" do
    it "requires a supported font file" do
      expect {
        described_class.generate_letter_avatar(
          letter: "A",
          background_color: [198, 125, 40],
          font_path: nil,
          output_path: "/tmp/avatar.png",
        )
      }.to raise_error(ArgumentError, "font_path must reference a supported font file")
    end

    it "rejects an unapproved font file" do
      Dir.mktmpdir("discourse-vips-font") do |directory|
        font_path = File.join(directory, "NotoSans-Regular.woff2")
        File.write(font_path, "not a font")

        expect {
          described_class.generate_letter_avatar(
            letter: "A",
            background_color: [198, 125, 40],
            font_path:,
            output_path: "/tmp/avatar.png",
          )
        }.to raise_error(ArgumentError, "font_path must reference a supported font file")
      end
    end

    it "renders an opaque 360 by 360 RGB PNG" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        output_path = File.join(directory, "avatar.png")
        font_path = File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2")

        described_class.generate_letter_avatar(
          letter: "<",
          background_color: [198, 125, 40],
          font_path:,
          output_path:,
        )

        image = ChunkyPNG::Image.from_file(output_path)
        expect([image.width, image.height]).to eq([360, 360])
        expect(image.pixels.all? { |pixel| ChunkyPNG::Color.a(pixel) == 255 }).to eq(true)
        expect(image[0, 0]).to eq(ChunkyPNG::Color.rgb(198, 125, 40))
        expect(image.pixels.uniq.length).to be > 2
      end
    end
  end

  describe ".dominant_color" do
    it "returns an uppercase RGB hex color" do
      input_path = file_from_fixtures("cropped.png").path

      expect(described_class.dominant_color(input_path:)).to eq("3A3730")
    end

    it "accepts a supported image with a nonstandard file extension" do
      Tempfile.create(%w[dominant-color .bin], binmode: true) do |file|
        file.write(File.binread(file_from_fixtures("cropped.png").path))
        file.flush

        expect(described_class.dominant_color(input_path: file.path)).to eq("3A3730")
      end
    end

    it "rejects unsupported image content" do
      input_path = file_from_fixtures("image.svg").path

      expect { described_class.dominant_color(input_path:) }.to raise_error(DiscourseVips::Error)
    end

    it "handles concurrent image operations" do
      input_path = file_from_fixtures("cropped.png").path

      colors =
        Array.new(4) { Thread.new { described_class.dominant_color(input_path:) } }.map(&:value)

      expect(colors).to eq(%w[3A3730 3A3730 3A3730 3A3730])
    end

    it "records image-processing instrumentation" do
      SiteSetting.instrument_image_processing = true
      input_path = file_from_fixtures("cropped.png").path

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          described_class.dominant_color(input_path:)
        end

      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(
        operation: "upload_dominant_color",
        success: true,
      )
      expect(payload[:duration_seconds]).to be >= 0
    end
  end

  describe ".generate_topic_og_image" do
    it "rasterizes SVG" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        output_path = File.join(directory, "topic.png")
        svg_path = file_from_fixtures("image.svg").path

        described_class.generate_topic_og_image(svg_path:, output_path:)

        expect(FastImage.type(output_path)).to eq(:png)
      end
    end

    it "rejects raster input" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        expect {
          described_class.generate_topic_og_image(
            svg_path: file_from_fixtures("logo.png").path,
            output_path: File.join(directory, "topic.png"),
          )
        }.to raise_error(DiscourseVips::Error)
      end
    end
  end
end

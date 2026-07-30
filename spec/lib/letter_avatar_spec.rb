# frozen_string_literal: true

require "base64"
require "chunky_png"
require "letter_avatar"

RSpec.describe LetterAvatar do
  def letter_avatar_changed_pixel_count(expected, actual)
    width = [expected.width, actual.width].max
    height = [expected.height, actual.height].max
    changed_pixel_count =
      height.times.sum do |y_position|
        width.times.count do |x_position|
          expected_pixel = expected[x_position, y_position] if x_position < expected.width &&
            y_position < expected.height
          actual_pixel = actual[x_position, y_position] if x_position < actual.width &&
            y_position < actual.height

          expected_pixel != actual_pixel
        end
      end

    [changed_pixel_count, width * height]
  end

  def write_letter_avatar_pixel_diff(comparisons, report_directory)
    FileUtils.mkdir_p(report_directory)

    comparison_sections =
      comparisons.map do |comparison|
        letter = comparison[:letter]
        expected = comparison[:expected]
        actual = comparison[:actual]
        width = [expected.width, actual.width].max
        height = [expected.height, actual.height].max
        diff = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)

        height.times do |y_position|
          width.times do |x_position|
            expected_pixel = expected[x_position, y_position] if x_position < expected.width &&
              y_position < expected.height
            actual_pixel = actual[x_position, y_position] if x_position < actual.width &&
              y_position < actual.height

            diff[x_position, y_position] = if expected_pixel.nil? && actual_pixel.nil?
              ChunkyPNG::Color::TRANSPARENT
            elsif expected_pixel == actual_pixel
              ChunkyPNG::Color.rgba(
                ChunkyPNG::Color.r(actual_pixel) / 4,
                ChunkyPNG::Color.g(actual_pixel) / 4,
                ChunkyPNG::Color.b(actual_pixel) / 4,
                ChunkyPNG::Color.a(actual_pixel),
              )
            else
              ChunkyPNG::Color.rgba(255, 0, 255, 255)
            end
          end
        end

        expected_path = report_directory.join("#{letter}-expected.png")
        actual_path = report_directory.join("#{letter}-actual.png")
        diff_path = report_directory.join("#{letter}-diff.png")
        expected.save(expected_path)
        actual.save(actual_path)
        diff.save(diff_path)

        expected_data = Base64.strict_encode64(File.binread(expected_path))
        actual_data = Base64.strict_encode64(File.binread(actual_path))
        diff_data = Base64.strict_encode64(File.binread(diff_path))
        changed_pixel_count = comparison[:changed_pixel_count]
        pixel_count = comparison[:pixel_count]
        changed_percentage = pixel_count.zero? ? 0 : (changed_pixel_count.fdiv(pixel_count) * 100)

        <<~HTML
          <section>
            <h2>#{letter}: #{changed_pixel_count}/#{pixel_count} pixels differ (#{format("%.2f", changed_percentage)}%)</h2>
            <div class="images">
              <figure><figcaption>Expected</figcaption><img src="data:image/png;base64,#{expected_data}" alt="Expected #{letter}"></figure>
              <figure><figcaption>Actual</figcaption><img src="data:image/png;base64,#{actual_data}" alt="Actual #{letter}"></figure>
              <figure><figcaption>Diff (changed pixels are magenta)</figcaption><img src="data:image/png;base64,#{diff_data}" alt="Pixel diff for #{letter}"></figure>
            </div>
          </section>
        HTML
      end

    report = <<~HTML
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>LetterAvatar pixel diff</title>
          <style>
            body { color: #222; font: 16px/1.5 sans-serif; margin: 2rem; }
            section { border-top: 1px solid #ccc; margin-top: 2rem; }
            .images { display: flex; flex-wrap: wrap; gap: 2rem; }
            figure { margin: 0; }
            img { image-rendering: pixelated; width: 180px; height: 180px; }
          </style>
        </head>
        <body>
          <h1>LetterAvatar pixel diff</h1>
          <p>Baseline: Linux</p>
          #{comparison_sections.join}
        </body>
      </html>
    HTML

    File.write(report_directory.join("index.html"), report)
  end

  describe ".cleanup_old" do
    it "removes stale cache directories" do
      path = LetterAvatar.cache_path

      FileUtils.mkdir_p(path + "junk")
      LetterAvatar.generate("test", 100)

      LetterAvatar.cleanup_old

      expect(Dir.entries(File.dirname(path)).length).to eq(3)
    end
  end

  describe ".generate" do
    it "generates a bounded PNG avatar" do
      username = "image-processing-regression"
      path = LetterAvatar.generate(username, 45, cache: false)

      expect(FastImage.type(path)).to eq(:png)
      expect(FastImage.size(path)).to eq([45, 45])
      expect(File.size(path)).to be_between(100, 5000)
    ensure
      if path
        identity = LetterAvatar::Identity.from_username(username)
        FileUtils.rm_f(path)
        FileUtils.rm_f(LetterAvatar.fullsize_path(identity))
      end
    end

    it "matches the A-Z pixel baselines" do
      if RbConfig::CONFIG["host_os"].match?(/darwin/i)
        skip("Linux CI owns the LetterAvatar pixel baselines.")
      end

      letters = ("A".."Z").to_a
      avatar_size = 45
      baseline_directory = Rails.root.join("spec/fixtures/images/letter_avatar_visual/linux")
      generated_paths = {}
      letters.each do |letter|
        generated_paths[letter] = described_class.generate(letter, avatar_size, cache: false)
      end
      update_baselines = ENV["UPDATE_LETTER_AVATAR_PIXEL_BASELINES"] == "1"

      if update_baselines
        FileUtils.mkdir_p(baseline_directory)
        generated_paths.each do |letter, generated_path|
          FileUtils.cp(generated_path, baseline_directory.join("#{letter}.png"))
        end
        skip(
          "Updated Linux baselines in #{baseline_directory}; rerun without UPDATE_LETTER_AVATAR_PIXEL_BASELINES.",
        )
      end

      missing_baselines =
        letters.reject { |letter| baseline_directory.join("#{letter}.png").exist? }
      if missing_baselines.any?
        skip(
          "Missing Linux baselines for #{missing_baselines.join(", ")}. " \
            "Generate them with `UPDATE_LETTER_AVATAR_PIXEL_BASELINES=1 bin/rspec spec/lib/letter_avatar_spec.rb`.",
        )
      end

      comparisons =
        generated_paths.map do |letter, generated_path|
          expected = ChunkyPNG::Image.from_file(baseline_directory.join("#{letter}.png"))
          actual = ChunkyPNG::Image.from_file(generated_path)
          changed_pixel_count, pixel_count = letter_avatar_changed_pixel_count(expected, actual)

          {
            letter: letter,
            expected: expected,
            actual: actual,
            pixel_count: pixel_count,
            changed_pixel_count: changed_pixel_count,
          }
        end

      if ENV["LETTER_AVATAR_PIXEL_DIFF_DEBUG"] == "1"
        write_letter_avatar_pixel_diff(comparisons, Rails.root.join("tmp/letter-avatar-pixel-diff"))
      end

      aggregate_failures "A-Z letter avatar pixels" do
        comparisons.each do |comparison|
          letter = comparison[:letter]
          expected = comparison[:expected]
          actual = comparison[:actual]
          changed_pixel_count = comparison[:changed_pixel_count]
          pixel_count = comparison[:pixel_count]

          expect(actual.width).to eq(expected.width),
          "#{letter}: actual width #{actual.width} did not match expected width #{expected.width}"
          expect(actual.height).to eq(expected.height),
          "#{letter}: actual height #{actual.height} did not match expected height #{expected.height}"
          expect(changed_pixel_count).to eq(0),
          "#{letter}: #{changed_pixel_count}/#{pixel_count} RGBA pixels differ; " \
            "run with LETTER_AVATAR_PIXEL_DIFF_DEBUG=1 and open tmp/letter-avatar-pixel-diff/index.html"
        end
      end
    ensure
      generated_paths&.each do |letter, generated_path|
        identity = LetterAvatar::Identity.from_username(letter)
        FileUtils.rm_f(generated_path)
        FileUtils.rm_f(described_class.fullsize_path(identity))
      end
    end
  end
end

# frozen_string_literal: true

require "base64"
require "letter_avatar"

RSpec.describe LetterAvatar do
  describe ".generate" do
    it "generates a visual comparison report" do
      report_path = Rails.root.join("tmp/letter-avatar-visual/index.html")
      run_command = "LETTER_AVATAR_VISUAL=1 bin/rspec spec/lib/letter_avatar_visual_spec.rb"
      unless ENV["LETTER_AVATAR_VISUAL"] == "1"
        skip("Run `#{run_command}` to generate #{report_path}.")
      end

      username = "image-processing-regression"
      avatar_size = 45
      platform = RbConfig::CONFIG["host_os"].match?(/darwin/i) ? "macos" : "linux"
      baseline_path = Rails.root.join("spec/fixtures/images/letter_avatar_visual/#{platform}.png")
      generated_path = described_class.generate(username, avatar_size, cache: false)
      report_directory = report_path.dirname
      actual_path = report_directory.join("actual.png")

      FileUtils.mkdir_p(report_directory)
      FileUtils.cp(generated_path, actual_path)

      actual_data = Base64.strict_encode64(File.binread(actual_path))
      if baseline_path.exist?
        expected_data = Base64.strict_encode64(File.binread(baseline_path))
        expected_image = <<~HTML
          <img src="data:image/png;base64,#{expected_data}" alt="Expected letter avatar">
        HTML
        baseline_status = baseline_path.to_s
      else
        expected_image = <<~HTML
          <p class="missing">No #{platform} baseline is available.</p>
        HTML
        baseline_status = "Missing: #{baseline_path}"
      end

      regeneration_command = "cp #{actual_path} #{baseline_path}"
      report = <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>LetterAvatar visual comparison</title>
            <style>
              body { color: #222; font: 16px/1.5 sans-serif; margin: 2rem; }
              code { background: #eee; padding: 0.15rem 0.3rem; }
              .comparison { display: flex; flex-wrap: wrap; gap: 2rem; }
              .panel { border: 1px solid #ccc; padding: 1rem; }
              .native img { height: #{avatar_size}px; width: #{avatar_size}px; }
              .enlarged img { height: #{avatar_size * 8}px; width: #{avatar_size * 8}px; }
              .missing { height: #{avatar_size}px; margin: 0; width: 16rem; }
            </style>
          </head>
          <body>
            <h1>LetterAvatar visual comparison</h1>
            <dl>
              <dt>Username</dt><dd><code>#{username}</code></dd>
              <dt>Platform</dt><dd><code>#{platform}</code></dd>
              <dt>Size</dt><dd>#{avatar_size} × #{avatar_size} pixels</dd>
              <dt>Baseline</dt><dd><code>#{baseline_status}</code></dd>
            </dl>
            <h2>Native size</h2>
            <div class="comparison native">
              <section class="panel"><h3>Expected</h3>#{expected_image}</section>
              <section class="panel"><h3>Actual</h3><img src="data:image/png;base64,#{actual_data}" alt="Actual letter avatar"></section>
            </div>
            <h2>8× enlargement</h2>
            <div class="comparison enlarged">
              <section class="panel"><h3>Expected</h3>#{expected_image}</section>
              <section class="panel"><h3>Actual</h3><img src="data:image/png;base64,#{actual_data}" alt="Actual letter avatar"></section>
            </div>
            <h2>Commands</h2>
            <p>Regenerate this report with <code>#{run_command}</code>.</p>
            <p>After visual review, update the #{platform} baseline with <code>#{regeneration_command}</code>.</p>
          </body>
        </html>
      HTML

      File.write(report_path, report)

      expect(report_path).to exist
      skip("Generated #{report_path}; #{baseline_status}") unless baseline_path.exist?
    ensure
      if generated_path
        identity = LetterAvatar::Identity.from_username(username)
        FileUtils.rm_f(generated_path)
        FileUtils.rm_f(described_class.fullsize_path(identity))
      end
    end
  end
end

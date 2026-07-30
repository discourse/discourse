# frozen_string_literal: true

require "base64"
require "letter_avatar"

RSpec.describe LetterAvatar do
  describe ".generate" do
    it "generates an A-Z visual comparison report" do
      report_path = Rails.root.join("tmp/letter-avatar-visual/index.html")
      run_command = "LETTER_AVATAR_VISUAL=1 bin/rspec spec/lib/letter_avatar_visual_spec.rb"
      regeneration_command =
        "LETTER_AVATAR_VISUAL=1 UPDATE_LETTER_AVATAR_BASELINES=1 bin/rspec spec/lib/letter_avatar_visual_spec.rb"
      unless ENV["LETTER_AVATAR_VISUAL"] == "1"
        skip("Run `#{run_command}` to generate #{report_path}.")
      end

      letters = ("A".."Z").to_a
      avatar_size = 45
      platform = RbConfig::CONFIG["host_os"].match?(/darwin/i) ? "macos" : "linux"
      baseline_directory = Rails.root.join("spec/fixtures/images/letter_avatar_visual/#{platform}")
      report_directory = report_path.dirname
      generated_paths =
        letters.to_h do |letter|
          [letter, Pathname(described_class.generate(letter, avatar_size, cache: false))]
        end

      FileUtils.mkdir_p(report_directory)
      if ENV["UPDATE_LETTER_AVATAR_BASELINES"] == "1"
        FileUtils.mkdir_p(baseline_directory)
        generated_paths.each do |letter, generated_path|
          FileUtils.cp(generated_path, baseline_directory.join("#{letter}.png"))
        end
      end

      missing_baselines =
        letters.reject { |letter| baseline_directory.join("#{letter}.png").exist? }
      comparisons =
        generated_paths.map do |letter, generated_path|
          baseline_path = baseline_directory.join("#{letter}.png")
          actual_data = Base64.strict_encode64(File.binread(generated_path))
          expected_image =
            if baseline_path.exist?
              expected_data = Base64.strict_encode64(File.binread(baseline_path))
              <<~HTML
                <img src="data:image/png;base64,#{expected_data}" alt="Expected #{letter} letter avatar">
              HTML
            else
              <<~HTML
                <p class="missing">No #{platform} baseline.</p>
              HTML
            end

          <<~HTML
            <section class="letter">
              <h2>#{letter}</h2>
              <div class="comparison native">
                <div><h3>Expected</h3>#{expected_image}</div>
                <div><h3>Actual</h3><img src="data:image/png;base64,#{actual_data}" alt="Actual #{letter} letter avatar"></div>
              </div>
              <div class="comparison enlarged">
                <div><h3>Expected (4×)</h3>#{expected_image}</div>
                <div><h3>Actual (4×)</h3><img src="data:image/png;base64,#{actual_data}" alt="Actual #{letter} letter avatar enlarged"></div>
              </div>
            </section>
          HTML
        end
      baseline_status =
        if missing_baselines.empty?
          baseline_directory.to_s
        else
          "Missing #{missing_baselines.join(", ")} in #{baseline_directory}"
        end
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
              .letters { display: grid; gap: 1.5rem; grid-template-columns: repeat(auto-fit, minmax(28rem, 1fr)); }
              .letter { border: 1px solid #ccc; padding: 1rem; }
              .letter h2 { margin-top: 0; }
              .comparison { align-items: start; display: grid; gap: 1rem; grid-template-columns: 1fr 1fr; }
              .comparison div { min-width: 0; }
              .comparison h3 { font-size: 1rem; }
              .native img { height: #{avatar_size}px; width: #{avatar_size}px; }
              .enlarged img { height: #{avatar_size * 4}px; width: #{avatar_size * 4}px; }
              .missing { height: #{avatar_size}px; margin: 0; width: 16rem; }
            </style>
          </head>
          <body>
            <h1>LetterAvatar visual comparison</h1>
            <dl>
              <dt>Platform</dt><dd><code>#{platform}</code></dd>
              <dt>Size</dt><dd>#{avatar_size} × #{avatar_size} pixels</dd>
              <dt>Baseline</dt><dd><code>#{baseline_status}</code></dd>
            </dl>
            <p>Regenerate this report with <code>#{run_command}</code>.</p>
            <p>After visual review, update every #{platform} baseline with <code>#{regeneration_command}</code>.</p>
            <main class="letters">
              #{comparisons.join}
            </main>
          </body>
        </html>
      HTML

      File.write(report_path, report)

      expect(report_path).to exist
      skip("Generated #{report_path}; #{baseline_status}") if missing_baselines.any?
    ensure
      generated_paths&.each do |letter, generated_path|
        identity = LetterAvatar::Identity.from_username(letter)
        FileUtils.rm_f(generated_path)
        FileUtils.rm_f(described_class.fullsize_path(identity))
      end
    end
  end
end

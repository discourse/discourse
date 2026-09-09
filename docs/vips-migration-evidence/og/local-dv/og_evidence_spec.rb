require "rails_helper"
require "chunky_png"
require "digest"
require "fileutils"
require "json"

RSpec.configure { |config| config.seed = 20_260_909 }

RSpec.describe TopicOgImageGenerator do
  describe "#generate_bytes" do
    it "records both renderers across scripts and palettes" do
      seed = 20_260_909
      srand(seed)
      frozen_at = Time.utc(2026, 9, 9, 12, 0, 0)
      freeze_time(frozen_at)
      SiteSetting.title = "Example Forum"
      SiteSetting.read_time_word_count = 225
      Discourse.stubs(:current_hostname).returns("forum.example")

      output_directory = Rails.root.join("public/discourse-task/og-evidence")
      FileUtils.mkdir_p(output_directory)
      author =
        Fabricate(
          :user,
          username: "evidence_author",
          name: "Evidence Author",
          email: "evidence-author@example.invalid",
        )
      category = Fabricate(:category, name: "General", color: "0088cc")
      topic = Fabricate(:topic, user: author, category:, created_at: frozen_at)
      topic.update_columns(like_count: 42, posts_count: 13, word_count: 1800)

      logo_svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="240" height="100">
          <defs>
            <linearGradient id="logo-gradient" x1="0" y1="0" x2="1" y2="1">
              <stop stop-color="#0088cc"/>
              <stop offset="1" stop-color="#00c8a0"/>
            </linearGradient>
          </defs>
          <rect x="4" y="8" width="80" height="80" rx="18" fill="url(#logo-gradient)"/>
          <circle cx="44" cy="48" r="20" fill="white"/>
          <path d="M30 61v17l20-17" fill="white"/>
          <text x="98" y="60" font-family="sans-serif" font-size="30" font-weight="700" fill="#123456">FORUM</text>
        </svg>
      SVG
      logo_url = "/evidence-logo.svg"
      logo_upload = Struct.new(:url, :width, :height).new(logo_url, 240, 100)
      logo_data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64(logo_svg)}"
      avatar = ChunkyPNG::Image.new(120, 120, ChunkyPNG::Color.rgb(255, 196, 64))
      avatar.rect(0, 0, 59, 119, ChunkyPNG::Color.rgb(36, 80, 144), ChunkyPNG::Color.rgb(36, 80, 144))
      avatar.circle(60, 60, 31, ChunkyPNG::Color::WHITE, ChunkyPNG::Color::WHITE)
      avatar.rect(52, 31, 68, 89, ChunkyPNG::Color.rgb(24, 48, 80), ChunkyPNG::Color.rgb(24, 48, 80))
      avatar_data_uri = "data:image/png;base64,#{Base64.strict_encode64(avatar.to_blob)}"
      avatar_url = author.avatar_template_url.gsub("{size}", "120")

      SiteSetting.stubs(:logo).returns(logo_upload)
      described_class.any_instance.stubs(:fetch_as_data_uri).returns(nil)
      described_class.any_instance.stubs(:fetch_as_data_uri).with(logo_url).returns(logo_data_uri)
      described_class.any_instance.stubs(:fetch_as_data_uri).with(avatar_url).returns(avatar_data_uri)

      scripts = {
        "latin" => {
          category: "General discussion",
          title: "Configure your community for thoughtful conversations and discover better ways to share knowledge",
        },
        "accented" => {
          category: "Développement",
          title: "Café déjà vu : créez une communauté accueillante où chacun échange des idées et partage ses découvertes",
        },
        "cjk" => {
          category: "技术讨论",
          title: "如何建立一个欢迎所有人的在线社区并通过深入交流分享知识经验共同解决问题探索新的想法和持续改进讨论体验",
        },
        "arabic" => {
          category: "مناقشات المجتمع",
          title: "كيف نبني مجتمعًا يرحب بالجميع ويشجع على تبادل الأفكار والخبرات وتطوير النقاشات المفيدة بين الأعضاء",
        },
      }
      palettes = {
        "light" => { "primary" => "183048", "secondary" => "f5f0e8", "tertiary" => "0088cc" },
        "dark" => { "primary" => "eee8de", "secondary" => "182432", "tertiary" => "44bbdd" },
      }
      manifest = {
        seed:,
        frozen_time: frozen_at.iso8601,
        hostname: "forum.example",
        site_title: SiteSetting.title,
        ruby: RUBY_DESCRIPTION,
        libvips: DiscourseVips.version,
        imagemagick: ImageMagick.magick("-version", operation: :topic_og_evidence_version).lines.first.strip,
        nokogiri: Nokogiri::VERSION,
        rspec_seed: RSpec.configuration.seed,
        cases: [],
      }

      palettes.each do |palette_name, colors|
        scheme =
          Fabricate(
            :color_scheme,
            color_scheme_colors:
              colors.map { |name, hex| Fabricate.build(:color_scheme_color, name:, hex:) },
          )
        SiteSetting.default_theme_id = Fabricate(:theme, color_scheme: scheme).id

        scripts.each do |script_name, attributes|
          category.update!(name: attributes.fetch(:category))
          topic.update_columns(title: attributes.fetch(:title))
          entry = {
            script: script_name,
            palette: palette_name,
            colors:,
            title: topic.title,
            category: category.name,
            outputs: {},
          }

          { "imagemagick" => false, "libvips" => true }.each do |backend, enabled|
            global_setting :enable_vips_image_processing, enabled
            bytes = described_class.new(topic).generate_bytes
            raise "#{script_name}/#{palette_name}/#{backend} produced no PNG" if bytes.blank?

            filename = "#{script_name}-#{palette_name}-#{backend}.png"
            File.binwrite(output_directory.join(filename), bytes)
            png = ChunkyPNG::Image.from_blob(bytes)
            entry[:outputs][backend] = {
              filename:,
              sha256: Digest::SHA256.hexdigest(bytes),
              bytes: bytes.bytesize,
              width: png.width,
              height: png.height,
            }
          end

          manifest[:cases] << entry
        end
      end

      File.write(output_directory.join("manifest.json"), JSON.pretty_generate(manifest) + "\n")
      puts "OG evidence: #{output_directory} (#{manifest[:cases].length} pairs)"
    end
  end
end

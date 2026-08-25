# frozen_string_literal: true

require "chunky_png"

RSpec.describe TopicOgImageGenerator do
  fab!(:category) { Fabricate(:category, name: "Feature", color: "0088cc") }
  fab!(:topic) do
    Fabricate(
      :topic,
      title: "How to configure your Discourse site for best results",
      category: category,
    )
  end

  # 1x1 transparent PNG as a test fixture for data URI embedding
  TINY_PNG_DATA_URI =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

  before do
    topic.update_columns(like_count: 42, posts_count: 13)
    TopicOgImageGenerator.any_instance.stubs(:fetch_as_data_uri).returns(TINY_PNG_DATA_URI)
  end

  describe "#generate" do
    it "generates a PNG upload for a topic" do
      generator = described_class.new(topic)
      generator.stubs(:render_png).returns(File.binread(file_from_fixtures("logo.png").path))
      upload = generator.generate

      expect(upload).to be_a(Upload)
      expect(upload.errors).to be_empty
      expect(upload.extension).to eq("png")
      expect(upload.original_filename).to eq("topic-og-#{topic.id}.png")
    end
  end

  describe "#generate_bytes" do
    it "renders the topic OG image as a 1200x630 PNG" do
      png_bytes = described_class.new(topic).generate_bytes

      expect(png_bytes).to be_present
      Tempfile.create(%w[topic-og .png], binmode: true) do |file|
        file.write(png_bytes)
        file.flush

        expect(FastImage.type(file.path)).to eq(:png)
        expect(FastImage.size(file.path)).to eq([1200, 630])
      end
    end

    it "renders raster and SVG assets in their expected regions" do
      logo_upload = Struct.new(:url, :width, :height).new("/marked-logo.svg", 200, 100)
      logo_svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
          <rect width="200" height="100" fill="#00ff00"/>
        </svg>
      SVG
      avatar_png = ChunkyPNG::Image.new(16, 16, ChunkyPNG::Color.rgb(255, 0, 0)).to_blob
      logo_data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64(logo_svg)}"
      avatar_data_uri = "data:image/png;base64,#{Base64.strict_encode64(avatar_png)}"
      avatar_url = topic.user.avatar_template_url.gsub("{size}", "120")
      SiteSetting.stubs(:logo).returns(logo_upload)
      described_class
        .any_instance
        .stubs(:fetch_as_data_uri)
        .with("/marked-logo.svg")
        .returns(logo_data_uri)
      described_class
        .any_instance
        .stubs(:fetch_as_data_uri)
        .with(avatar_url)
        .returns(avatar_data_uri)

      png = ChunkyPNG::Image.from_blob(described_class.new(topic).generate_bytes)

      avatar_pixel = png[116, 339]
      logo_pixel = png[180, 520]
      expect(
        [
          [ChunkyPNG::Color.r(avatar_pixel), ChunkyPNG::Color.g(avatar_pixel)],
          [ChunkyPNG::Color.g(logo_pixel), ChunkyPNG::Color.r(logo_pixel)],
        ],
      ).to eq([[255, 0], [255, 0]])
    end

    it "omits an unrenderable SVG asset and still renders the canvas" do
      logo_upload = Struct.new(:url, :width, :height).new("/invalid-logo.svg", 200, 100)
      invalid_svg_data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64("<svg><invalid")}"
      avatar_url = topic.user.avatar_template_url.gsub("{size}", "120")
      SiteSetting.stubs(:logo).returns(logo_upload)
      described_class
        .any_instance
        .stubs(:fetch_as_data_uri)
        .with("/invalid-logo.svg")
        .returns(invalid_svg_data_uri)
      described_class.any_instance.stubs(:fetch_as_data_uri).with(avatar_url).returns(nil)
      png = ChunkyPNG::Image.from_blob(described_class.new(topic).generate_bytes)

      expect([png.width, png.height]).to eq([1200, 630])
      expect(png[180, 520]).to eq(png[500, 520])
    end

    it "returns nil when the final image cannot be rendered" do
      DiscourseVips.stubs(:vips).raises(Discourse::Utils::CommandError, "invalid image")

      expect(described_class.new(topic).generate_bytes).to eq(nil)
    end
  end

  describe ".eligible?" do
    it "returns true for a public topic in a public category" do
      expect(described_class.eligible?(topic)).to eq(true)
    end

    it "returns false when topic is nil" do
      expect(described_class.eligible?(nil)).to eq(false)
    end

    it "returns false when login_required is enabled" do
      SiteSetting.login_required = true
      expect(described_class.eligible?(topic)).to eq(false)
    end

    it "returns false for a personal message" do
      pm = Fabricate(:private_message_topic)
      expect(described_class.eligible?(pm)).to eq(false)
    end

    it "returns false for a topic in a read-restricted category" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      topic.update!(category: private_category)
      expect(described_class.eligible?(topic)).to eq(false)
    end
  end

  describe "#build_svg (via send)" do
    it "includes the topic title limited to two lines" do
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).to include("How to configure your")
      title_line_count = svg.scan(/font-size="62"/).length
      expect(title_line_count).to eq(2)
    end

    it "adds ellipsis when title exceeds two lines" do
      long_title =
        "This is a very long topic title that will definitely wrap onto more than two lines and require truncation with an ellipsis at the end"
      topic.update!(title: long_title)

      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      title_line_count = svg.scan(/font-size="62"/).length
      expect(title_line_count).to eq(TopicOgImageGenerator::MAX_TITLE_LINES)
      expect(svg).to include("…")
    end

    it "includes category name" do
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).to include("Feature")
      expect(svg).to include("0088cc")
    end

    it "includes stats separated by middle dots" do
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).to include("12 replies  ·  42 likes")
    end

    it "includes author avatar and username" do
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).to include(topic.user.username)
      expect(svg).to include("avatar-clip")
      expect(svg).to include(topic.created_at.strftime("%b %-d, %Y"))
    end

    it "embeds images as data URIs" do
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).to include("data:image/png;base64,")
      expect(svg).not_to match(%r{href="https?://})
    end

    it "escapes XML entities in title" do
      topic.update!(title: "Using <script> tags & other HTML elements safely")
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).not_to include("<script>")
      expect(svg).to include("&lt;script&gt;")
      expect(svg).to include("&amp;")
    end

    it "does not include site name text" do
      SiteSetting.title = "My Test Forum"
      generator = described_class.new(topic)
      svg = generator.send(:build_svg)

      expect(svg).not_to include("My Test Forum")
    end
  end
end

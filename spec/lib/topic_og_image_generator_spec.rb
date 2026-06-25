# frozen_string_literal: true

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
      # Stub the ImageMagick rasterization: rendering an SVG to PNG depends on the
      # ImageMagick/font setup of the host, which isn't reliable across CI and dev
      # environments. Here we assert that #generate turns rendered bytes into a
      # proper PNG Upload.
      generator.stubs(:render_png).returns(File.binread(file_from_fixtures("logo.png").path))
      upload = generator.generate

      expect(upload).to be_a(Upload)
      expect(upload.errors).to be_empty
      expect(upload.extension).to eq("png")
      expect(upload.original_filename).to eq("topic-og-#{topic.id}.png")
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

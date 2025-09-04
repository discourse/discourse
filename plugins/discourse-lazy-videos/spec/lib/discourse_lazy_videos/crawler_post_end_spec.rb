# frozen_string_literal: true

describe DiscourseLazyVideos::CrawlerPostEnd do
  fab!(:topic)
  fab!(:post1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post2) { Fabricate(:post, topic: topic, post_number: 2) }

  let(:controller) { TopicsController.new }
  let(:topic_view) { TopicView.new(topic) }
  let(:post_crawler_schema) { described_class.new(controller, post1) }

  before do
    SiteSetting.lazy_videos_enabled = true
    controller.instance_variable_set(:@topic_view, topic_view)
  end

  describe "#html" do
    context "when not on TopicsController" do
      let(:controller) { ApplicationController.new }
      let(:schema) { described_class.new(controller, post1) }

      it "returns empty string" do
        expect(schema.html).to eq("")
      end
    end

    context "when lazy_videos_enabled is false" do
      before { SiteSetting.lazy_videos_enabled = false }

      it "returns empty string" do
        expect(post_crawler_schema.html).to eq("")
      end
    end

    context "when no post is set" do
      let(:schema) { described_class.new(controller, nil) }

      it "returns empty string" do
        expect(schema.html).to eq("")
      end
    end

    context "when post has no videos" do
      it "returns empty string" do
        post1.update!(cooked: "<p>Just some text without videos</p>")

        expect(post_crawler_schema.html).to eq("")
      end
    end

    context "when first post has a YouTube video" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="youtube-onebox lazy-video-container"
            data-video-id="dQw4w9WgXcQ"
            data-video-title="Rick Astley - Never Gonna Give You Up"
            data-provider-name="youtube">
            <a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ">
              <img src="https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"
                title="Rick Astley - Never Gonna Give You Up">
            </a>
          </div>
        HTML

      it "generates VideoObject schema" do
        html = post_crawler_schema.html

        expect(html).to include('<script type="application/ld+json">')
        expect(html).to include('"@type":"VideoObject"')
        expect(html).to include('"name":"Rick Astley - Never Gonna Give You Up"')
        expect(html).to include('"embedUrl":"https://www.youtube.com/embed/dQw4w9WgXcQ"')
        expect(html).to include(
          '"thumbnailUrl":"https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"',
        )
      end

      it "includes post URL and upload date" do
        html = post_crawler_schema.html

        expect(html).to include('"url":"' + post1.full_url)
        expect(html).to include('"uploadDate":"' + post1.created_at.iso8601)
      end
    end

    context "when non-first post has a video" do
      before { post2.update!(cooked: <<~HTML) }
          <div class="vimeo-onebox lazy-video-container"
            data-video-id="123456"
            data-video-title="Vimeo Video"
            data-provider-name="vimeo">
            <a href="https://vimeo.com/123456">
              <img src="https://example.com/thumbnail.jpg">
            </a>
          </div>
        HTML

      it "uses the comment post URL" do
        schema = described_class.new(controller, post2)
        html = schema.html

        expect(html).to include('"url":"' + post2.full_url)
      end
    end

    context "when post has multiple videos" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="youtube-onebox lazy-video-container"
            data-video-id="video1"
            data-video-title="Video 1"
            data-provider-name="youtube">
            <a href="https://www.youtube.com/watch?v=video1">
              <img src="https://img.youtube.com/vi/video1/maxresdefault.jpg">
            </a>
          </div>
          <div class="vimeo-onebox lazy-video-container"
            data-video-id="123456"
            data-video-title="Video 2"
            data-provider-name="vimeo">
            <a href="https://vimeo.com/123456">
              <img src="https://example.com/thumbnail.jpg">
            </a>
          </div>
        HTML

      it "generates separate schemas for each video" do
        html = post_crawler_schema.html

        expect(html.scan('<script type="application/ld+json">').count).to eq(2)
        expect(html).to include('"embedUrl":"https://www.youtube.com/embed/video1"')
        expect(html).to include('"embedUrl":"https://player.vimeo.com/video/123456"')
      end
    end

    context "when post has a TikTok video" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="tiktok-onebox lazy-video-container"
            data-video-id="7181751442041220378"
            data-video-title="TikTok Video"
            data-provider-name="tiktok">
            <a href="https://www.tiktok.com/@user/video/7181751442041220378">
              <img src="https://example.com/tiktok-thumbnail.jpg">
            </a>
          </div>
        HTML

      it "generates TikTok VideoObject schema" do
        html = post_crawler_schema.html

        expect(html).to include('"embedUrl":"https://www.tiktok.com/embed/v2/7181751442041220378"')
      end
    end

    context "with escaping and security" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="youtube-onebox lazy-video-container"
            data-video-id="test123"
            data-video-title="Title with &quot;quotes&quot; and &lt;tags&gt;"
            data-provider-name="youtube">
            <a href="https://youtube.com/watch?v=test123">
              <img src="https://img.youtube.com/vi/test123/maxresdefault.jpg">
            </a>
          </div>
        HTML

      it "properly escapes special characters" do
        html = post_crawler_schema.html

        expect(html).to include('<script type="application/ld+json">')
        expect(html).to include("</script>")

        parsed = JSON.parse(html.match(%r{<script[^>]*>(.*?)</script>}m)[1])
        expect(parsed["name"]).to eq('Title with "quotes" and <tags>')
      end
    end

    context "with missing video data" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="lazy-video-container"
            data-video-id="test123">
            <a href="https://youtube.com/watch?v=test123">
              <img src="https://img.youtube.com/vi/test123/maxresdefault.jpg">
            </a>
          </div>
        HTML

      it "returns empty when provider is missing" do
        expect(post_crawler_schema.html).to eq("")
      end
    end

    context "with invalid provider" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="lazy-video-container"
            data-video-id="test123"
            data-provider-name="invalid">
            <a href="https://example.com/video">
              <img src="https://example.com/thumb.jpg">
            </a>
          </div>
        HTML

      it "returns empty for unsupported providers" do
        expect(post_crawler_schema.html).to eq("")
      end
    end

    context "when contentUrl is provided" do
      before { post1.update!(cooked: <<~HTML) }
          <div class="youtube-onebox lazy-video-container"
            data-video-id="test123"
            data-video-title="Test Video"
            data-provider-name="youtube">
            <a href="https://www.youtube.com/watch?v=test123">
              <img src="https://img.youtube.com/vi/test123/maxresdefault.jpg">
            </a>
          </div>
        HTML

      it "includes contentUrl from the anchor href" do
        html = post_crawler_schema.html

        expect(html).to include('"contentUrl":"https://www.youtube.com/watch?v=test123"')
      end
    end

    context "when post has both text content and video" do
      before do
        post1.update!(
          raw: "Check out this amazing video! It's a classic that everyone should watch.",
        )

        post1.update_columns(cooked: <<~HTML)
          <p>Check out this amazing video! It's a classic that everyone should watch.</p>
          <div class="youtube-onebox lazy-video-container"
            data-video-id="test123"
            data-video-title="Test Video"
            data-provider-name="youtube">
            <a href="https://www.youtube.com/watch?v=test123">
              <img src="https://img.youtube.com/vi/test123/maxresdefault.jpg">
            </a>
          </div>
        HTML

        post1.reload
      end

      it "includes description from post excerpt" do
        expect(post1.raw).to include("Check out this amazing video")
        expect(post1.cooked).to include("lazy-video-container")

        excerpt = post1.excerpt(200, strip_links: true, text_entities: true)
        expect(excerpt).to be_present
        expect(excerpt).to include("Check out")

        html = post_crawler_schema.html

        expect(html).not_to be_empty
        expect(html).to include('"description":')
        parsed = JSON.parse(html.match(%r{<script[^>]*>(.*?)</script>}m)[1])
        expect(parsed["description"]).to include("Check out this amazing video")
      end
    end
  end
end

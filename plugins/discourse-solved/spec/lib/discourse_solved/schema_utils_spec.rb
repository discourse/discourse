# frozen_string_literal: true

RSpec.describe DiscourseSolved::SchemaUtils do
  before do
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.solved_add_schema_markup = "always"
  end

  describe ".qa_page_schema?" do
    # A fresh topic per example avoids the memoized @qa_page_schema bleeding between tests.

    it "returns true when an eligible text reply exists" do
      topic = Fabricate(:topic_with_op)
      Fabricate(:post, topic:, raw: "This is a written answer")

      expect(described_class.qa_page_schema?(topic)).to eq(true)
    end

    it "returns false when the only replies are textless onebox-only posts" do
      topic = Fabricate(:topic_with_op)
      Fabricate(
        :post,
        topic:,
        raw: "https://www.youtube.com/watch?v=test",
        cooked:
          '<div class="onebox video-onebox"><iframe src="https://youtube.com/embed/test"></iframe></div>',
      )

      expect(described_class.qa_page_schema?(topic)).to eq(false)
    end
  end

  describe ".post_text" do
    fab!(:topic, :topic_with_op)

    it "returns the whole post rather than an excerpt" do
      words = Array.new(120) { |i| "word#{i}" }.join(" ")
      post = Fabricate(:post, topic:, raw: words)

      expect(words.length).to be > SiteSetting.post_excerpt_maxlength
      expect(described_class.post_text(post)).to eq(words)
    end

    it "returns plain text, with links, entities and code blocks flattened" do
      post =
        Fabricate(
          :post,
          topic:,
          raw: "See [the docs](https://example.com/docs) & ask\n\n```\nputs 1 < 2\n```",
        )

      expect(described_class.post_text(post)).to eq("See the docs & ask\n\nputs 1 < 2")
    end

    it "leaves quotes out unless the post is nothing but a quote" do
      quoting_post = Fabricate(:post, topic:, raw: "[quote]\nquoted words\n[/quote]\n\nown words")
      quote_only_post = Fabricate(:post, topic:, raw: "[quote]\nquoted words\n[/quote]")

      expect(described_class.post_text(quoting_post)).to eq("own words")
      expect(described_class.post_text(quote_only_post)).to eq("quoted words")
    end

    it "keeps the text around an [excerpt] block" do
      post =
        Fabricate(
          :post,
          topic:,
          raw: "Context before.\n\n[excerpt]Summary[/excerpt]\n\nActual question here.",
        )

      expect(described_class.post_text(post)).to eq(
        "Context before.\n\nSummary\n\nActual question here.",
      )
    end

    it "keeps the body of a details block, not just its summary" do
      post =
        Fabricate(
          :post,
          topic:,
          raw: "[details=\"Logs\"]\nhidden lines\n[/details]\n\nVisible after.",
          cooked:
            "<details>\n<summary>Logs</summary>\n<p>hidden lines</p>\n</details>\n<p>Visible after.</p>",
        )

      expect(described_class.post_text(post)).to eq("Logs\n\nhidden lines\n\nVisible after.")
    end
  end
end

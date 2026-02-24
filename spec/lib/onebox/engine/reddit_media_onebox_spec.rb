# frozen_string_literal: true

RSpec.describe Onebox::Engine::RedditMediaOnebox do
  let(:image_link) do
    "https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition"
  end
  let(:self_post_link) do
    "https://www.reddit.com/r/LocalLLaMA/comments/xyz789/what_are_some_underrated_local_llms"
  end
  let(:video_link) { "https://www.reddit.com/r/cats/comments/abc123/my_cat_doing_a_backflip" }

  describe "image post" do
    let(:html) { described_class.new(image_link).to_html }

    before do
      stub_request(:get, "#{image_link}.json").to_return(
        status: 200,
        body: onebox_response("reddit_image"),
      )
    end

    it "includes image" do
      expect(html).to include("https://i.redd.it/vsg59iw0srn21.jpg")
    end

    it "includes title" do
      expect(html).to include("Literally nothing black edition")
    end

    it "includes subreddit" do
      expect(html).to include("r/colors")
    end

    it "includes score and comments" do
      expect(html).to include("4 points")
      expect(html).to include("1 comments")
    end
  end

  describe "self/text post" do
    let(:html) { described_class.new(self_post_link).to_html }

    before do
      stub_request(:get, "#{self_post_link}.json").to_return(
        status: 200,
        body: onebox_response("reddit_self_post"),
      )
    end

    it "includes title" do
      expect(html).to include("What are some underrated local LLMs?")
    end

    it "includes selftext" do
      expect(html).to include("experimenting with various local models")
    end

    it "includes author" do
      expect(html).to include("u/llm_enthusiast")
    end

    it "does not include image markup" do
      expect(html).not_to include("scale-image")
    end
  end

  describe "video post" do
    let(:html) { described_class.new(video_link).to_html }

    before do
      stub_request(:get, "#{video_link}.json").to_return(
        status: 200,
        body: onebox_response("reddit_video"),
      )
    end

    it "includes title" do
      expect(html).to include("My cat doing a backflip")
    end

    it "includes preview thumbnail" do
      expect(html).to include("thumbnail")
    end

    it "includes preview image" do
      expect(html).to include("https://preview.redd.it/abc123def456.png")
    end
  end

  describe ".===" do
    it "matches valid Reddit URL" do
      valid_url = URI(image_link)
      expect(described_class === valid_url).to eq(true)
    end

    it "matches old.reddit.com URL" do
      expect(described_class === URI("https://old.reddit.com/r/cats/comments/abc123/post/")).to eq(
        true,
      )
    end

    it "matches np.reddit.com URL" do
      expect(described_class === URI("https://np.reddit.com/r/cats/comments/abc123/post/")).to eq(
        true,
      )
    end

    it "matches new.reddit.com URL" do
      expect(described_class === URI("https://new.reddit.com/r/cats/comments/abc123/post/")).to eq(
        true,
      )
    end

    it "does not match invalid Reddit URL" do
      invalid_url = URI("https://www.reddit.com.somedomain.com/r/colors/comments/b4d5xm/")
      expect(described_class === invalid_url).to eq(false)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Onebox::Engine::RedditMediaOnebox do
  let(:post_link) do
    "https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition"
  end
  let(:comment_link) do
    "https://www.reddit.com/r/cats/comments/abc123/my_cat_doing_a_backflip/def456"
  end

  describe "#placeholder_html" do
    it "returns a generic placeholder" do
      expect(described_class.new(post_link).placeholder_html).to include("placeholder-icon generic")
    end
  end

  describe "#to_html" do
    it "renders a native Reddit embed iframe" do
      html = described_class.new(post_link).to_html

      expect(html).to include("<iframe")
      expect(html).to include('class="reddit-onebox"')
      expect(html).to include(
        "https://embed.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition/",
      )
      expect(html).to include("embed=true")
      expect(html).to include('height="500"')
      expect(html).not_to include("scrolling=")
      expect(html).not_to include("frameborder=")
    end

    it "does not fetch Reddit content server-side" do
      described_class.new(post_link).to_html

      expect(WebMock).not_to have_requested(:any, %r{reddit\.com/.*(?:\.json|access_token)})
    end
  end

  describe "comment permalinks" do
    it "adds the native comment embed params" do
      html = described_class.new(comment_link).to_html

      expect(html).to include(
        "https://embed.reddit.com/r/cats/comments/abc123/my_cat_doing_a_backflip/def456/",
      )
      expect(html).to include("showmedia=false")
      expect(html).to include("showmore=false")
      expect(html).to include("depth=1")
      expect(html).to include("context=1")
      expect(html).to include('height="300"')
    end
  end

  describe ".===" do
    it "allows both Reddit embed iframe origins" do
      expect(described_class.iframe_origins).to contain_exactly(
        "https://embed.reddit.com",
        "https://sh.reddit.com",
      )
    end

    it "matches valid Reddit URL" do
      valid_url = URI(post_link)
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

    it "matches Reddit user comment URLs" do
      expect(
        described_class === URI("https://www.reddit.com/user/spez/comments/abc123/post/def456/"),
      ).to eq(true)
    end

    it "does not match invalid Reddit URL" do
      invalid_url = URI("https://www.reddit.com.somedomain.com/r/colors/comments/b4d5xm/")
      expect(described_class === invalid_url).to eq(false)
    end
  end
end

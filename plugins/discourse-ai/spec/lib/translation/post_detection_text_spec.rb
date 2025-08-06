# frozen_string_literal: true

describe DiscourseAi::Translation::PostDetectionText do
  before { enable_current_plugin }

  describe ".get_text" do
    let(:post) { Fabricate.build(:post) }

    it "returns nil when post is nil" do
      expect(described_class.get_text(nil)).to be_nil
    end

    it "returns nil when post.cooked is nil" do
      post.cooked = nil
      expect(described_class.get_text(post)).to be_nil
    end

    it "handles simple text" do
      post.cooked = "<p>Hello world</p>"
      expect(described_class.get_text(post)).to eq("Hello world")
    end

    it "removes quotes" do
      post.cooked = "<p>Hello </p><blockquote><p>Quote</p></blockquote><p>World</p>"
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes Discourse quotes" do
      post.cooked = '<p>Hello </p><aside class="quote"><p>Quote</p></aside><p>World</p>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes image captions" do
      post.cooked = '<p>Hello </p><div class="lightbox-wrapper">Caption text</div><p>World</p>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes oneboxes" do
      post.cooked = '<p>Hello </p><aside class="onebox">Onebox content</aside><p>World</p>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes code blocks" do
      post.cooked = "<p>Hello </p><pre><code>Code block</code></pre><p>World</p>"
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes hashtags" do
      post.cooked = '<p>Hello </p><a class="hashtag-cooked">#hashtag</a><p>World</p>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes emoji" do
      post.cooked = '<p>Hello </p><img class="emoji" alt=":smile:" title=":smile:"><p>World</p>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "removes mentions" do
      post.cooked = '<p>Hello </p><a class="mention">@user</a><p>World</p>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end

    it "falls back to necessary text when preferred is empty" do
      post.cooked = '<aside class="quote">Quote</aside><a class="mention">@user</a>'
      expect(described_class.get_text(post)).to eq("@user")
    end

    it "falls back to cooked when all filtering removes all content" do
      post.cooked = "<blockquote>Quote</blockquote>"
      expect(described_class.get_text(post)).to eq("Quote")
    end

    it "handles complex nested content correctly" do
      post.cooked =
        '<p>Hello </p><div class="lightbox-wrapper"><p>Image caption</p><img src="test.jpg"></div><blockquote><p>Quote text</p></blockquote><p>World</p><pre><code>Code block</code></pre><a class="mention">@user</a>'
      expect(described_class.get_text(post)).to eq("Hello World")
    end
  end
end

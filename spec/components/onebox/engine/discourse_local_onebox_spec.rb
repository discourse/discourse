require 'rails_helper'

describe Onebox::Engine::DiscourseLocalOnebox do
  it "matches for a topic url" do
    url = "#{Discourse.base_url}/t/hot-topic"
    expect(Onebox.has_matcher?(url)).to eq(true)
    expect(Onebox::Matcher.new(url).oneboxed).to eq(described_class)
  end

  it "matches for a post url" do
    url = "#{Discourse.base_url}/t/hot-topic/23/2"
    expect(Onebox.has_matcher?(url)).to eq(true)
    expect(Onebox::Matcher.new(url).oneboxed).to eq(described_class)
  end

  context "for a link to a post" do
    let(:post)  { Fabricate(:post) }
    let(:post2) { Fabricate(:post, topic: post.topic, post_number: 2) }

    it "returns a link if post isn't found" do
      url = "#{Discourse.base_url}/t/not-exist/3/2"
      expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
    end

    it "returns a link if not allowed to see the post" do
      url = "#{Discourse.base_url}#{post2.url}"
      Guardian.any_instance.stubs(:can_see?).returns(false)
      expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
    end

    it "returns a link if post is hidden" do
      hidden_post = Fabricate(:post, topic: post.topic, post_number: 2, hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached])
      url = "#{Discourse.base_url}#{hidden_post.url}"
      expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
    end

    it "returns some onebox goodness if post exists and can be seen" do
      url = "#{Discourse.base_url}#{post2.url}?source_topic_id=#{post2.topic_id+1}"
      Guardian.any_instance.stubs(:can_see?).returns(true)
      html = Onebox.preview(url).to_s
      expect(html).to include(post2.excerpt)
      expect(html).to include(post2.topic.title)

      url = "#{Discourse.base_url}#{post2.url}"
      html = Onebox.preview(url).to_s
      expect(html).to include(post2.user.username)
      expect(html).to include(post2.excerpt)
    end
  end

  context "for a link to a topic" do
    let(:post)  { Fabricate(:post) }
    let(:topic) { post.topic }

    before { topic.last_posted_at = Time.zone.now; topic.save; } # otherwise errors

    it "returns a link if topic isn't found" do
      url = "#{Discourse.base_url}/t/not-found/123"
      expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
    end

    it "returns a link if not allowed to see the post" do
      url = topic.url
      Guardian.any_instance.stubs(:can_see?).returns(false)
      expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
    end

    it "replaces emoji in the title" do
      topic.update_column(:title, "Who wants to eat a :hamburger:")
      expect(Onebox.preview(topic.url).to_s).to match(/hamburger.png/)
    end

    it "returns some onebox goodness if post exists and can be seen" do
      SiteSetting.external_system_avatars_enabled = false
      url = "#{topic.url}"
      Guardian.any_instance.stubs(:can_see?).returns(true)
      html = Onebox.preview(url).to_s
      expect(html).to include(topic.posts.first.user.username)
      expect(html).to include("topic-info")
    end
  end

  context "for a link to an internal audio or video file" do

    it "returns nil if file type is not audio or video" do
      url = "#{Discourse.base_url}/uploads/default/original/3X/5/c/24asdf42.pdf"
      expect(Onebox.preview(url).to_s).to eq("")
    end

    it "returns some onebox goodness for audio file" do
      url = "#{Discourse.base_url}/uploads/default/original/3X/5/c/24asdf42.mp3"
      html = Onebox.preview(url).to_s
      expect(html).to eq("<audio controls><source src='#{url}'><a href='#{url}'>#{url}</a></audio>")
    end

    it "returns some onebox goodness for video file" do
      url = "#{Discourse.base_url}/uploads/default/original/3X/5/c/24asdf42.mp4"
      html = Onebox.preview(url).to_s
      expect(html).to eq("<video width='100%' height='100%' controls><source src='#{url}'><a href='#{url}'>#{url}</a></video>")
    end
  end

  context "When deployed to a subfolder" do
    let(:base_url) { "http://test.localhost/subfolder" }
    let(:base_uri) { "/subfolder" }

    before do
      Discourse.stubs(:base_url).returns(base_url)
      Discourse.stubs(:base_uri).returns(base_uri)
    end

    it "matches for a topic url" do
      url = "#{Discourse.base_url}/t/hot-topic"
      expect(Onebox.has_matcher?(url)).to eq(true)
      expect(Onebox::Matcher.new(url).oneboxed).to eq(described_class)
    end

    it "matches for a post url" do
      url = "#{Discourse.base_url}/t/hot-topic/23/2"
      expect(Onebox.has_matcher?(url)).to eq(true)
      expect(Onebox::Matcher.new(url).oneboxed).to eq(described_class)
    end

    context "for a link to a post" do
      let(:post)  { Fabricate(:post) }
      let(:post2) { Fabricate(:post, topic: post.topic, post_number: 2) }

      it "returns a link if post isn't found" do
        url = "#{Discourse.base_url}/t/not-exist/3/2"
        expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
      end

      it "returns a link if not allowed to see the post" do
        url = "#{Discourse.base_url}#{post2.url}"
        Guardian.any_instance.stubs(:can_see?).returns(false)
        expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
      end

      it "returns a link if post is hidden" do
        hidden_post = Fabricate(:post, topic: post.topic, post_number: 2, hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached])
        url = "#{Discourse.base_url}#{hidden_post.url}"
        expect(Onebox.preview(url).to_s).to eq("<a href='#{url}'>#{url}</a>")
      end

      it "returns some onebox goodness if post exists and can be seen" do
        url = "#{Discourse.base_url}#{post2.url}?source_topic_id=#{post2.topic_id+1}"
        Guardian.any_instance.stubs(:can_see?).returns(true)
        html = Onebox.preview(url).to_s
        expect(html).to include(post2.excerpt)
        expect(html).to include(post2.topic.title)

        url = "#{Discourse.base_url}#{post2.url}"
        html = Onebox.preview(url).to_s
        expect(html).to include(post2.user.username)
        expect(html).to include(post2.excerpt)
      end
    end
  end
end

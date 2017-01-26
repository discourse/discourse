require 'rails_helper'

describe Onebox::Engine::DiscourseLocalOnebox do

  before { SiteSetting.external_system_avatars_enabled = false }

  context "for a link to a post" do
    let(:post)  { Fabricate(:post) }
    let(:post2) { Fabricate(:post, topic: post.topic, post_number: 2) }

    it "returns a link if post isn't found" do
      url = "#{Discourse.base_url}/t/not-exist/3/2"
      expect(Onebox.preview(url).to_s).to eq(%|<a href="#{url}">#{url}</a>|)
    end

    it "returns a link if not allowed to see the post" do
      url = "#{Discourse.base_url}#{post2.url}"
      Guardian.any_instance.expects(:can_see_post?).returns(false)
      expect(Onebox.preview(url).to_s).to eq(%|<a href="#{url}">#{url}</a>|)
    end

    it "returns a link if post is hidden" do
      hidden_post = Fabricate(:post, topic: post.topic, post_number: 2, hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached])
      url = "#{Discourse.base_url}#{hidden_post.url}"
      expect(Onebox.preview(url).to_s).to eq(%|<a href="#{url}">#{url}</a>|)
    end

    it "returns some onebox goodness if post exists and can be seen" do
      url = "#{Discourse.base_url}#{post2.url}?source_topic_id=#{post2.topic_id+1}"
      html = Onebox.preview(url).to_s
      expect(html).to include(post2.excerpt)
      expect(html).to include(post2.topic.title)

      html = Onebox.preview("#{Discourse.base_url}#{post2.url}").to_s
      expect(html).to include(post2.user.username)
      expect(html).to include(post2.excerpt)
    end
  end

  context "for a link to a topic" do
    let(:post)  { Fabricate(:post) }
    let(:topic) { post.topic }

    it "returns a link if topic isn't found" do
      url = "#{Discourse.base_url}/t/not-found/123"
      expect(Onebox.preview(url).to_s).to eq(%|<a href="#{url}">#{url}</a>|)
    end

    it "returns a link if not allowed to see the topic" do
      url = topic.url
      Guardian.any_instance.expects(:can_see_topic?).returns(false)
      expect(Onebox.preview(url).to_s).to eq(%|<a href="#{url}">#{url}</a>|)
    end

    it "replaces emoji in the title" do
      topic.update_column(:title, "Who wants to eat a :hamburger:")
      expect(Onebox.preview(topic.url).to_s).to match(/hamburger\.png/)
    end

    it "returns some onebox goodness if topic exists and can be seen" do
      html = Onebox.preview(topic.url).to_s
      expect(html).to include(topic.ordered_posts.first.user.username)
      expect(html).to include("<blockquote>")
    end
  end

  context "for a link to an internal audio or video file" do

    let(:sha) { Digest::SHA1.hexdigest("discourse") }
    let(:path) { "/uploads/default/original/3X/5/c/#{sha}" }

    it "returns nil if file type is not audio or video" do
      url = "#{Discourse.base_url}#{path}.pdf"
      FakeWeb.register_uri(:get, url, body: "")
      expect(Onebox.preview(url).to_s).to eq("")
    end

    it "returns some onebox goodness for audio file" do
      url = "#{Discourse.base_url}#{path}.MP3"
      html = Onebox.preview(url).to_s
      # </source> will be removed by the browser
      # need to fix https://github.com/rubys/nokogumbo/issues/14
      expect(html).to eq(%|<audio controls=""><source src="#{url}"></source><a href="#{url}">#{url}</a></audio>|)
    end

    it "returns some onebox goodness for video file" do
      url = "#{Discourse.base_url}#{path}.mov"
      html = Onebox.preview(url).to_s
      expect(html).to eq(%|<video width="100%" height="100%" controls=""><source src="#{url}"></source><a href="#{url}">#{url}</a></video>|)
    end
  end

  context "When deployed to a subfolder" do
    let(:base_uri) { "/subfolder" }
    let(:base_url) { "http://test.localhost#{base_uri}" }

    before do
      Discourse.stubs(:base_url).returns(base_url)
      Discourse.stubs(:base_uri).returns(base_uri)
    end

    context "for a link to a post" do
      let(:post)  { Fabricate(:post) }
      let(:post2) { Fabricate(:post, topic: post.topic, post_number: 2) }

      it "returns some onebox goodness if post exists and can be seen" do
        url = "#{Discourse.base_url}#{post2.url}?source_topic_id=#{post2.topic_id+1}"
        html = Onebox.preview(url).to_s
        expect(html).to include(post2.excerpt)
        expect(html).to include(post2.topic.title)
      end
    end
  end

  context "When login_required is enabled" do
    before { SiteSetting.login_required = true }

    context "for a link to a topic" do
      let(:post)  { Fabricate(:post) }
      let(:topic) { post.topic }

      it "returns some onebox goodness if post exists and can be seen" do
        html = Onebox.preview(topic.url).to_s
        expect(html).to include(topic.ordered_posts.first.user.username)
        expect(html).to include("<blockquote>")
      end
    end

  end

end

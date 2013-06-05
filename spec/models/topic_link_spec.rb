require 'spec_helper'

describe TopicLink do

  it { should belong_to :topic }
  it { should belong_to :post }
  it { should belong_to :user }
  it { should have_many :topic_link_clicks }
  it { should validate_presence_of :url }

  def test_uri
    URI.parse(Discourse.base_url)
  end

  before do
    @topic = Fabricate(:topic, title: 'unique topic name')
    @user = @topic.user
  end

  it "can't link to the same topic" do
    ftl = TopicLink.new(url: "/t/#{@topic.id}",
                              topic_id: @topic.id,
                              link_topic_id: @topic.id)
    ftl.valid?.should be_false
  end

  describe 'external links' do
    before do
      @post = Fabricate(:post_with_external_links, user: @user, topic: @topic)
      TopicLink.extract_from(@post)
    end

    it 'works' do
      # has the forum topic links
      @topic.topic_links.count.should == 4

      # works with markdown links
      @topic.topic_links.exists?(url: "http://forumwarz.com").should be_true

      #works with markdown links followed by a period
      @topic.topic_links.exists?(url: "http://www.codinghorror.com/blog").should be_true
    end

  end

  describe 'internal links' do

    context "rendered onebox" do

      before do
        @other_topic = Fabricate(:topic, user: @user)
        @other_topic.posts.create(user: @user, raw: "some content for the first post")
        @other_post = @other_topic.posts.create(user: @user, raw: "some content for the second post")

        @url = "http://#{test_uri.host}/t/#{@other_topic.slug}/#{@other_topic.id}/#{@other_post.post_number}"

        @topic.posts.create(user: @user, raw: 'initial post')
        @post = @topic.posts.create(user: @user, raw: "Link to another topic:\n\n#{@url}\n\n")
        @post.reload
        TopicLink.extract_from(@post)

        @link = @topic.topic_links.first
      end

      it 'works' do
        # should have a link
        @link.should be_present
        # should be the canonical URL
        @link.url.should == @url
      end

    end

    context 'topic link' do
      before do
        @other_topic = Fabricate(:topic, user: @user)
        @other_post = @other_topic.posts.create(user: @user, raw: "some content")

        @url = "http://#{test_uri.host}/t/#{@other_topic.slug}/#{@other_topic.id}"

        @topic.posts.create(user: @user, raw: 'initial post')
        @post = @topic.posts.create(user: @user, raw: "Link to another topic: #{@url}")

        TopicLink.extract_from(@post)

        @link = @topic.topic_links.first
      end

      it 'works' do
        # extracted the link
        @link.should be_present

        # is set to internal
        @link.should be_internal

        # has the correct url
        @link.url.should == @url

        # has the extracted domain
        @link.domain.should == test_uri.host

        # should have the id of the linked forum
        @link.link_topic_id == @other_topic.id

        # should not be the reflection
        @link.should_not be_reflection
      end

      describe 'reflection in the other topic' do

        before do
          @reflection = @other_topic.topic_links.first
        end

        it 'works' do
          # exists
          @reflection.should be_present
          @reflection.should be_reflection
          @reflection.post_id.should be_present
          @reflection.domain.should == test_uri.host
          @reflection.url.should == "http://#{test_uri.host}/t/unique-topic-name/#{@topic.id}/#{@post.post_number}"
          @reflection.link_topic_id.should == @topic.id
          @reflection.link_post_id.should == @post.id

          #has the user id of the original link
          @reflection.user_id.should == @link.user_id
        end
      end

      context 'removing a link' do

        before do
          @post.revise(@post.user, "no more linkies")
          TopicLink.extract_from(@post)
        end

        it 'should remove the link' do
          @topic.topic_links.where(post_id: @post.id).should be_blank
          # should remove the reflected link
          @reflection = @other_topic.topic_links.should be_blank
        end
      end
    end

    context "link to a user on discourse" do
      let(:post) { @topic.posts.create(user: @user, raw: "<a href='/users/#{@user.username_lower}'>user</a>") }
      before do
        TopicLink.extract_from(post)
      end

      it 'does not extract a link' do
        @topic.topic_links.should be_blank
      end
    end

    context "link to a discourse resource like a FAQ" do
      let(:post) { @topic.posts.create(user: @user, raw: "<a href='/faq'>faq link here</a>") }
      before do
        TopicLink.extract_from(post)
      end

      it 'does not extract a link' do
        @topic.topic_links.should be_present
      end
    end

    context "@mention links" do
      let(:post) { @topic.posts.create(user: @user, raw: "Hey @#{@user.username_lower}") }

      before do
        TopicLink.extract_from(post)
      end

      it 'does not extract a link' do
        @topic.topic_links.should be_blank
      end
    end

  end

  describe 'internal link from pm' do
    before do
      @pm = Fabricate(:topic, user: @user, archetype: 'private_message')
      @other_post = @pm.posts.create(user: @user, raw: "some content")

      @url = "http://#{test_uri.host}/t/topic-slug/#{@topic.id}"

      @pm.posts.create(user: @user, raw: 'initial post')
      @linked_post = @pm.posts.create(user: @user, raw: "Link to another topic: #{@url}")

      TopicLink.extract_from(@linked_post)

      @link = @topic.topic_links.first
    end

    it 'should not create a reflection' do
      @topic.topic_links.first.should be_nil
    end

    it 'should not create a normal link' do
      @pm.topic_links.first.should_not be_nil
    end
  end

  describe 'internal link with non-standard port' do
    it 'includes the non standard port if present' do
      @other_topic = Fabricate(:topic, user: @user)
      SiteSetting.stubs(:port).returns(5678)
      alternate_uri = URI.parse(Discourse.base_url)
      @url = "http://#{alternate_uri.host}:5678/t/topic-slug/#{@other_topic.id}"
      @post = @topic.posts.create(user: @user,
                                         raw: "Link to another topic: #{@url}")
      TopicLink.extract_from(@post)
      @reflection = @other_topic.topic_links.first
      @reflection.url.should == "http://#{alternate_uri.host}:5678/t/unique-topic-name/#{@topic.id}"
    end
  end

end

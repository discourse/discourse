require 'discourse'
require 'spec_helper'

describe TopicLinkClick do

  it { should belong_to :topic_link }
  it { should belong_to :user }
  it { should validate_presence_of :topic_link_id }

  def test_uri
    URI.parse('http://test.host')
  end

  context 'topic_links' do
    before do
      @topic = Fabricate(:topic)
      @post = Fabricate(:post_with_external_links, user: @topic.user, topic: @topic)
      TopicLink.extract_from(@post)
      @topic_link = @topic.topic_links.first
    end

    it 'has 0 clicks at first' do
      @topic_link.clicks.should == 0
    end

    context 'create' do
      before do
        TopicLinkClick.create(topic_link: @topic_link, ip_address: '192.168.1.1')
      end

      it 'creates the forum topic link click' do
        TopicLinkClick.count.should == 1
      end

      it 'has 0 clicks at first' do
        @topic_link.reload
        @topic_link.clicks.should == 1
      end

      it 'serializes and deserializes the IP' do
        TopicLinkClick.first.ip_address.to_s.should == '192.168.1.1'
      end

    end

    context 'create_from' do

      context 'without a url' do
        let(:click) { TopicLinkClick.create_from(url: "url that doesn't exist", post_id: @post.id, ip: '127.0.0.1') }

        it "returns nil" do
          click.should be_nil
        end
      end

      context 'clicking on your own link' do
        it "should not record the click" do
          lambda {
            TopicLinkClick.create_from(url: @topic_link.url, post_id: @post.id, ip: '127.0.0.1', user_id: @post.user_id)
          }.should_not change(TopicLinkClick, :count)
        end
      end

      context 'with a valid url and post_id' do
        before do
          @url = TopicLinkClick.create_from(url: @topic_link.url, post_id: @post.id, ip: '127.0.0.1')
          @click = TopicLinkClick.last
        end

        it 'creates a click' do
          @click.should be_present
        end

        it 'has the topic_link id' do
          @click.topic_link.should == @topic_link
        end

        it "returns the url clicked on" do
          @url.should == @topic_link.url
        end

        context "clicking again" do
          it "should not record the click due to rate limiting" do
            -> { TopicLinkClick.create_from(url: @topic_link.url, post_id: @post.id, ip: '127.0.0.1') }.should_not change(TopicLinkClick, :count)
          end
        end
      end

      context 'with a valid url and topic_id' do
        before do
          @url = TopicLinkClick.create_from(url: @topic_link.url, topic_id: @topic.id, ip: '127.0.0.1')
          @click = TopicLinkClick.last
        end

        it 'creates a click' do
          @click.should be_present
        end

        it 'has the topic_link id' do
          @click.topic_link.should == @topic_link
        end

        it "returns the url linked to" do
          @url.should == @topic_link.url
        end
      end


    end

  end

end

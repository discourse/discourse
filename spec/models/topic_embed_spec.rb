require 'spec_helper'

describe TopicEmbed do

  it { should belong_to :topic }
  it { should belong_to :post }
  it { should validate_presence_of :embed_url }

  context '.import' do

    let(:user) { Fabricate(:user) }
    let(:title) { "How to turn a fish from good to evil in 30 seconds" }
    let(:url) { 'http://eviltrout.com/123' }
    let(:contents) { "hello world new post <a href='/hello'>hello</a> <img src='/images/wat.jpg'>" }

    it "returns nil when the URL is malformed" do
      TopicEmbed.import(user, "invalid url", title, contents).should be_nil
      TopicEmbed.count.should == 0
    end

    context 'creation of a post' do
      let!(:post) { TopicEmbed.import(user, url, title, contents) }

      it "works as expected with a new URL" do
        post.should be_present

        # It uses raw_html rendering
        post.cook_method.should == Post.cook_methods[:raw_html]
        post.cooked.should == post.raw

        # It converts relative URLs to absolute
        post.cooked.start_with?("hello world new post <a href=\"http://eviltrout.com/hello\">hello</a> <img src=\"http://eviltrout.com/images/wat.jpg\">").should be_true

        post.topic.has_topic_embed?.should be_true
        TopicEmbed.where(topic_id: post.topic_id).should be_present
      end

      it "Supports updating the post" do
        post = TopicEmbed.import(user, url, title, "muhahaha new contents!")
        post.cooked.should =~ /new contents/
      end

      it "Should leave uppercase Feed Entry URL untouched in content" do
        cased_url = 'http://eviltrout.com/ABCD'
        post = TopicEmbed.import(user, cased_url, title, "some random content")
        post.cooked.should =~ /#{cased_url}/
      end

      it "Should leave lowercase Feed Entry URL untouched in content" do
        cased_url = 'http://eviltrout.com/abcd'
        post = TopicEmbed.import(user, cased_url, title, "some random content")
        post.cooked.should =~ /#{cased_url}/
      end
    end

  end

end

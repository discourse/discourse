require 'spec_helper'

describe TopicEmbed do

  it { is_expected.to belong_to :topic }
  it { is_expected.to belong_to :post }
  it { is_expected.to validate_presence_of :embed_url }

  context '.import' do

    let(:user) { Fabricate(:user) }
    let(:title) { "How to turn a fish from good to evil in 30 seconds" }
    let(:url) { 'http://eviltrout.com/123' }
    let(:contents) { "hello world new post <a href='/hello'>hello</a> <img src='/images/wat.jpg'>" }
    let!(:embeddable_host) { Fabricate(:embeddable_host) }

    it "returns nil when the URL is malformed" do
      expect(TopicEmbed.import(user, "invalid url", title, contents)).to eq(nil)
      expect(TopicEmbed.count).to eq(0)
    end

    context 'creation of a post' do
      let!(:post) { TopicEmbed.import(user, url, title, contents) }

      it "works as expected with a new URL" do
        expect(post).to be_present

        # It uses raw_html rendering
        expect(post.cook_method).to eq(Post.cook_methods[:raw_html])
        expect(post.cooked).to eq(post.raw)

        # It converts relative URLs to absolute
        expect(post.cooked.start_with?("hello world new post <a href=\"http://eviltrout.com/hello\">hello</a> <img src=\"http://eviltrout.com/images/wat.jpg\">")).to eq(true)

        expect(post.topic.has_topic_embed?).to eq(true)
        expect(TopicEmbed.where(topic_id: post.topic_id)).to be_present

        expect(post.topic.category).to eq(embeddable_host.category)
      end

      it "Supports updating the post" do
        post = TopicEmbed.import(user, url, title, "muhahaha new contents!")
        expect(post.cooked).to match(/new contents/)
      end

      it "Should leave uppercase Feed Entry URL untouched in content" do
        cased_url = 'http://eviltrout.com/ABCD'
        post = TopicEmbed.import(user, cased_url, title, "some random content")
        expect(post.cooked).to match(/#{cased_url}/)
      end

      it "Should leave lowercase Feed Entry URL untouched in content" do
        cased_url = 'http://eviltrout.com/abcd'
        post = TopicEmbed.import(user, cased_url, title, "some random content")
        expect(post.cooked).to match(/#{cased_url}/)
      end
    end

  end

end

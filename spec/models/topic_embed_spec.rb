require 'rails_helper'
require 'stringio'

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
        expect(post.cooked).to have_tag('a', with: { href: 'http://eviltrout.com/hello' })
        expect(post.cooked).to have_tag('img', with: { src: 'http://eviltrout.com/images/wat.jpg' })

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

  describe '.find_remote' do

    context 'post with allowed classes "foo" and "emoji"' do

      let(:user) { Fabricate(:user) }
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      content = ''

      before(:each) do
        SiteSetting.stubs(:embed_classname_whitelist).returns 'emoji , foo'
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
        title, content = TopicEmbed.find_remote(url)
      end

      it 'img node has emoji class' do
        expect(content).to have_tag('img', with: { class: 'emoji' })
      end

      it 'img node has foo class' do
        expect(content).to have_tag('img', with: { class: 'foo' })
      end

      it 'p node has foo class' do
        expect(content).to have_tag('p', with: { class: 'foo' })
      end

      it 'nodes removes classes other than emoji' do
        expect(content).to have_tag('img', without: { class: 'other' })
      end

    end

    context 'post with no allowed classes' do

      let(:user) { Fabricate(:user) }
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      content = ''

      before(:each) do
        SiteSetting.stubs(:embed_classname_whitelist).returns ' '
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
        title, content = TopicEmbed.find_remote(url)
      end

      it 'img node doesn\'t have emoji class' do
        expect(content).to have_tag('img', without: { class: 'emoji' })
      end

      it 'img node doesn\'t have foo class' do
        expect(content).to have_tag('img', without: { class: 'foo' })
      end

      it 'p node doesn\'t foo class' do
        expect(content).to have_tag('p', without: { class: 'foo' })
      end

      it 'img node doesn\'t have other class' do
        expect(content).to have_tag('img', without: { class: 'other' })
      end

    end

  end

end

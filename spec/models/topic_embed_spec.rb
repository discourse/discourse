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

    context ".title_scrub" do

      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "<title>Through the Looking Glass - Classic Books</title><body>some content here</body>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      before do
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
      end

      it "doesn't scrub the title by default" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Through the Looking Glass - Classic Books")
      end

      it "scrubs the title when the option is enabled" do
        SiteSetting.embed_title_scrubber = " - Classic Books$"
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Through the Looking Glass")
      end

    end

    context 'post with allowed classes "foo" and "emoji"' do
      let(:user) { Fabricate(:user) }
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      response = nil

      before do
        SiteSetting.embed_classname_whitelist = 'emoji, foo'
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
        response = TopicEmbed.find_remote(url)
      end

      it "has no author tag" do
        expect(response.author).to be_blank
      end

      it 'img node has emoji class' do
        expect(response.body).to have_tag('img', with: { class: 'emoji' })
      end

      it 'img node has foo class' do
        expect(response.body).to have_tag('img', with: { class: 'foo' })
      end

      it 'p node has foo class' do
        expect(response.body).to have_tag('p', with: { class: 'foo' })
      end

      it 'nodes removes classes other than emoji' do
        expect(response.body).to have_tag('img', without: { class: 'other' })
      end
    end

    context 'post with author metadata' do
      let!(:user) { Fabricate(:user, username: 'eviltrout') }
      let(:url) { 'http://eviltrout.com/321' }
      let(:contents) { '<html><head><meta name="author" content="eviltrout"></head><body>rich and morty</body></html>' }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      response = nil

      before(:each) do
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
        response = TopicEmbed.find_remote(url)
      end

      it "has no author tag" do
        expect(response.author).to eq(user)
      end
    end

    context 'post with no allowed classes' do

      let(:user) { Fabricate(:user) }
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      response = nil

      before(:each) do
        SiteSetting.embed_classname_whitelist = ''
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
        response = TopicEmbed.find_remote(url)
      end

      it 'img node doesn\'t have emoji class' do
        expect(response.body).to have_tag('img', without: { class: 'emoji' })
      end

      it 'img node doesn\'t have foo class' do
        expect(response.body).to have_tag('img', without: { class: 'foo' })
      end

      it 'p node doesn\'t foo class' do
        expect(response.body).to have_tag('p', without: { class: 'foo' })
      end

      it 'img node doesn\'t have other class' do
        expect(response.body).to have_tag('img', without: { class: 'other' })
      end
    end

    context "non-ascii URL" do
      let(:url) { 'http://eviltrout.com/test/ماهی' }
      let(:contents) { "<title>سلام</title><body>این یک پاراگراف آزمون است.</body>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      before do
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open)
          .with('http://eviltrout.com/test/%D9%85%D8%A7%D9%87%DB%8C', allow_redirections: :safe).returns file
      end

      it "doesn't throw an error" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("سلام")
      end
    end

    context "encoded URL" do
      let(:url) { 'http://example.com/hello%20world' }
      let(:contents) { "<title>Hello World!</title><body></body>" }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      before do
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open)
          .with('http://example.com/hello%20world', allow_redirections: :safe).returns file
      end

      it "doesn't throw an error" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Hello World!")
      end
    end

    context "emails" do
      let(:url) { 'http://example.com/foo' }
      let(:contents) { '<p><a href="mailto:foo%40example.com">URL encoded @ symbol</a></p><p><a href="mailto:bar@example.com">normal mailto link</a></p>' }
      let!(:embeddable_host) { Fabricate(:embeddable_host) }
      let!(:file) { StringIO.new }

      before do
        file.stubs(:read).returns contents
        TopicEmbed.stubs(:open).returns file
      end

      it "handles mailto links" do
        response = TopicEmbed.find_remote(url)
        expect(response.body).to have_tag('a', with: { href: 'mailto:foo%40example.com' })
        expect(response.body).to have_tag('a', with: { href: 'mailto:bar@example.com' })
      end
    end
  end

  context ".escape_uri" do
    it "doesn't escape simple URL" do
      url = TopicEmbed.escape_uri('http://example.com/foo/bar')
      expect(url).to eq('http://example.com/foo/bar')
    end

    it "escapes unsafe chars" do
      url = TopicEmbed.escape_uri("http://example.com/?a=\11\15")
      expect(url).to eq('http://example.com/?a=%09%0D')
    end

    it "escapes non-ascii chars" do
      url = TopicEmbed.escape_uri('http://example.com/ماهی')
      expect(url).to eq('http://example.com/%D9%85%D8%A7%D9%87%DB%8C')
    end

    it "doesn't escape already escaped chars" do
      url = TopicEmbed.escape_uri('http://example.com/foo%20bar/foo bar/')
      expect(url).to eq('http://example.com/foo%20bar/foo%20bar/')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

describe TopicEmbed do

  it { is_expected.to belong_to :topic }
  it { is_expected.to belong_to :post }
  it { is_expected.to validate_presence_of :embed_url }

  context '.import' do

    fab!(:user) { Fabricate(:user) }
    let(:title) { "How to turn a fish from good to evil in 30 seconds" }
    let(:url) { 'http://eviltrout.com/123' }
    let(:contents) { "<p>hello world new post <a href='/hello'>hello</a> <img src='images/wat.jpg'></p>" }
    fab!(:embeddable_host) { Fabricate(:embeddable_host) }
    fab!(:category) { Fabricate(:category) }
    fab!(:tag) { Fabricate(:tag) }

    it "returns nil when the URL is malformed" do
      expect(TopicEmbed.import(user, "invalid url", title, contents)).to eq(nil)
      expect(TopicEmbed.count).to eq(0)
    end

    context 'creation of a post' do
      let!(:post) { TopicEmbed.import(user, url, title, contents) }
      let(:topic_embed) { TopicEmbed.find_by(post: post) }

      it "works as expected with a new URL" do
        expect(post).to be_present

        # It uses raw_html rendering
        expect(post.cook_method).to eq(Post.cook_methods[:raw_html])
        expect(post.cooked).to eq(post.raw)

        # It converts relative URLs to absolute
        expect(post.cooked).to have_tag('a', with: { href: 'http://eviltrout.com/hello' })
        expect(post.cooked).to have_tag('img', with: { src: 'http://eviltrout.com/images/wat.jpg' })

        # It converts relative URLs to absolute when expanded
        stub_request(:get, url).to_return(status: 200, body: contents)
        expect(TopicEmbed.expanded_for(post)).to have_tag('img', with: { src: 'http://eviltrout.com/images/wat.jpg' })

        expect(post.topic.has_topic_embed?).to eq(true)
        expect(TopicEmbed.where(topic_id: post.topic_id)).to be_present

        expect(post.topic.category).to eq(embeddable_host.category)
        expect(post.topic).not_to be_visible
      end

      it "Supports updating the post content" do
        expect do
          TopicEmbed.import(user, url, "New title received", "<p>muhahaha new contents!</p>")
        end.to change { topic_embed.reload.content_sha1 }
        expect(topic_embed.topic.title).to eq("New title received")

        expect(topic_embed.post.cooked).to match(/new contents/)
      end

      it "Supports updating the post author" do
        new_user = Fabricate(:user)
        TopicEmbed.import(new_user, url, title, contents)

        topic_embed.reload
        expect(topic_embed.post.user).to eq(new_user)
        expect(topic_embed.post.topic.user).to eq(new_user)
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

      it "will make the topic unlisted if `embed_unlisted` is set until someone replies" do
        Jobs.run_immediately!
        SiteSetting.embed_unlisted = true
        imported_post = TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content")
        expect(imported_post.topic).not_to be_visible
        pc = PostCreator.new(
          Fabricate(:user),
          raw: "this is a reply that will make the topic visible",
          topic_id: imported_post.topic_id,
          reply_to_post_number: 1
        )
        pc.create
        expect(imported_post.topic.reload).to be_visible
      end

      it "won't be invisible if `embed_unlisted` is set to false" do
        Jobs.run_immediately!
        SiteSetting.embed_unlisted = false
        imported_post = TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content")
        expect(imported_post.topic).to be_visible
      end

      it "creates the topic in the category passed as a parameter" do
        Jobs.run_immediately!
        imported_post = TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content", category_id: category.id)
        expect(imported_post.topic.category).not_to eq(embeddable_host.category)
        expect(imported_post.topic.category).to eq(category)
      end

      it "creates the topic with the tag passed as a parameter" do
        Jobs.run_immediately!
        SiteSetting.tagging_enabled = true
        imported_post = TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content", tags: [tag.name])
        expect(imported_post.topic.tags).to include(tag)
      end

      it "respects overriding the cook_method when asked" do
        Jobs.run_immediately!
        SiteSetting.embed_support_markdown = false
        stub_request(:get, "https://www.youtube.com/watch?v=K56soYl0U1w")
          .to_return(status: 200, body: "", headers: {})
        stub_request(:get, "https://www.youtube.com/embed/K56soYl0U1w")
          .to_return(status: 200, body: "", headers: {})

        imported_post = TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "https://www.youtube.com/watch?v=K56soYl0U1w", cook_method: Post.cook_methods[:regular])
        expect(imported_post.cooked).to match(/onebox|iframe/)
      end
    end

    context "post creation supports markdown rendering" do
      before do
        SiteSetting.embed_support_markdown = true
      end

      it "works as expected" do
        post = TopicEmbed.import(user, url, title, "some random content")
        expect(post).to be_present

        # It uses regular rendering
        expect(post.cook_method).to eq(Post.cook_methods[:regular])
      end
    end

    describe 'embedded content truncation' do
      MAX_LENGTH_BEFORE_TRUNCATION = 100

      let(:long_content) { "<p>#{'a' * MAX_LENGTH_BEFORE_TRUNCATION}</p>\n<p>more</p>" }

      it 'truncates the imported post when truncation is enabled' do
        SiteSetting.embed_truncate = true
        post = TopicEmbed.import(user, url, title, long_content)

        expect(post.raw).not_to include(long_content)
      end

      it 'keeps everything in the imported post when truncation is disabled' do
        SiteSetting.embed_truncate = false
        post = TopicEmbed.import(user, url, title, long_content)

        expect(post.raw).to include(long_content)
      end

      it 'looks at first div when there is no paragraph' do

        no_para = "<div><h>testing it</h></div>"

        SiteSetting.embed_truncate = true
        post = TopicEmbed.import(user, url, title, no_para)

        expect(post.raw).to include("testing it")
      end
    end
  end

  context '.topic_id_for_embed' do
    it "returns correct topic id irrespective of url protocol" do
      topic_embed = Fabricate(:topic_embed, embed_url: "http://example.com/post/248")

      expect(TopicEmbed.topic_id_for_embed('http://exAMPle.com/post/248')).to eq(topic_embed.topic_id)
      expect(TopicEmbed.topic_id_for_embed('https://example.com/post/248/')).to eq(topic_embed.topic_id)

      expect(TopicEmbed.topic_id_for_embed('http://example.com/post/248/2')).to eq(nil)
      expect(TopicEmbed.topic_id_for_embed('http://examples.com/post/248')).to eq(nil)
      expect(TopicEmbed.topic_id_for_embed('http://example.com/post/24')).to eq(nil)
      expect(TopicEmbed.topic_id_for_embed('http://example.com/post')).to eq(nil)
    end

    it "finds the topic id when the embed_url contains a query string" do
      topic_embed = Fabricate(:topic_embed, embed_url: "http://example.com/post/248?key=foo")
      expect(TopicEmbed.topic_id_for_embed('http://example.com/post/248?key=foo')).to eq(topic_embed.topic_id)
    end
  end

  describe '.find_remote' do
    fab!(:embeddable_host) { Fabricate(:embeddable_host) }

    context ".title_scrub" do
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "<title>Through the Looking Glass - Classic Books</title><body>some content here</body>" }

      before do
        stub_request(:get, url).to_return(status: 200, body: contents)
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
      fab!(:user) { Fabricate(:user) }
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>" }

      before do
        SiteSetting.allowed_embed_classnames = 'emoji, foo'
        stub_request(:get, url).to_return(status: 200, body: contents)
        @response = TopicEmbed.find_remote(url)
      end

      it "has no author tag" do
        expect(@response.author).to be_blank
      end

      it 'img node has emoji class' do
        expect(@response.body).to have_tag('img', with: { class: 'emoji' })
      end

      it 'img node has foo class' do
        expect(@response.body).to have_tag('img', with: { class: 'foo' })
      end

      it 'p node has foo class' do
        expect(@response.body).to have_tag('p', with: { class: 'foo' })
      end

      it 'nodes removes classes other than emoji' do
        expect(@response.body).to have_tag('img', without: { class: 'other' })
      end
    end

    context 'post with author metadata' do
      fab!(:user) { Fabricate(:user, username: 'eviltrout') }
      let(:url) { 'http://eviltrout.com/321' }
      let(:contents) { '<html><head><meta name="author" content="eviltrout"></head><body>rich and morty</body></html>' }

      before(:each) do
        stub_request(:get, url).to_return(status: 200, body: contents)
      end

      it "has no author tag" do
        response = TopicEmbed.find_remote(url)

        expect(response.author).to eq(user)
      end
    end

    context 'post with no allowed classes' do
      fab!(:user) { Fabricate(:user) }
      let(:url) { 'http://eviltrout.com/123' }
      let(:contents) { "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>" }

      before(:each) do
        SiteSetting.allowed_embed_classnames = ''
        stub_request(:get, url).to_return(status: 200, body: contents)
        @response = TopicEmbed.find_remote(url)
      end

      it 'img node doesn\'t have emoji class' do
        expect(@response.body).to have_tag('img', without: { class: 'emoji' })
      end

      it 'img node doesn\'t have foo class' do
        expect(@response.body).to have_tag('img', without: { class: 'foo' })
      end

      it 'p node doesn\'t foo class' do
        expect(@response.body).to have_tag('p', without: { class: 'foo' })
      end

      it 'img node doesn\'t have other class' do
        expect(@response.body).to have_tag('img', without: { class: 'other' })
      end
    end

    context "non-ascii URL" do
      let(:url) { 'http://eviltrout.com/test/ماهی' }
      let(:contents) { "<title>سلام</title><body>این یک پاراگراف آزمون است.</body>" }

      before do
        stub_request(:get, url).to_return(status: 200, body: contents)
      end

      it "doesn't throw an error" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("سلام")
      end
    end

    context "encoded URL" do
      let(:url) { 'http://example.com/hello%20world' }
      let(:contents) { "<title>Hello World!</title><body></body>" }

      before do
        stub_request(:get, url).to_return(status: 200, body: contents)
      end

      it "doesn't throw an error" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Hello World!")
      end
    end

    context "non-http URL" do
      it "throws an error" do
        url = '/test.txt'

        expect(TopicEmbed.find_remote(url)).to be_nil
      end
    end

    context "emails" do
      let(:url) { 'http://example.com/foo' }
      let(:contents) { '<p><a href="mailto:foo%40example.com">URL encoded @ symbol</a></p><p><a href="mailto:bar@example.com">normal mailto link</a></p>' }

      before do
        stub_request(:get, url).to_return(status: 200, body: contents)
      end

      it "handles mailto links" do
        response = TopicEmbed.find_remote(url)

        expect(response.body).to have_tag('a', with: { href: 'mailto:foo@example.com' })
        expect(response.body).to have_tag('a', with: { href: 'mailto:bar@example.com' })
      end
    end

    context "malformed href" do
      let(:url) { 'http://example.com/foo' }
      let(:contents) { '<p><a href="(http://foo.bar)">Baz</a></p>' }

      before do
        stub_request(:get, url).to_return(status: 200, body: contents)
      end

      it "doesn’t raise an exception" do
        expect { TopicEmbed.find_remote(url) }.not_to raise_error
      end
    end

    context 'canonical links' do
      let(:url) { 'http://eviltrout.com/123?asd' }
      let(:canonical_url) { 'http://eviltrout.com/123' }
      let(:content) { "<head><link rel=\"canonical\" href=\"#{canonical_url}\"></head>" }
      let(:canonical_content) {  "<title>Canonical</title><body></body>" }

      before do
        stub_request(:get, url).to_return(status: 200, body: content)
        stub_request(:head, canonical_url)
        stub_request(:get, canonical_url).to_return(status: 200, body: canonical_content)
      end

      it 'a' do
        response = TopicEmbed.find_remote(url)

        expect(response.title).to eq("Canonical")
      end

    end
  end

  describe '.absolutize_urls' do
    it "handles badly formed URIs" do
      invalid_url = 'http://source.com/#double#anchor'
      contents = "hello world new post <a href='/hello'>hello</a>"

      raw = TopicEmbed.absolutize_urls(invalid_url, contents)
      expect(raw).to eq("hello world new post <a href=\"http://source.com/hello\">hello</a>")
    end

    it "handles malformed links" do
      url = "https://somesource.com"

      contents = <<~CONTENT
      hello world new post <a href="mailto:somemail@somewhere.org>">hello</a>
      some image <img src="https:/><invalidimagesrc/">
      CONTENT

      raw = TopicEmbed.absolutize_urls(url, contents)
      expect(raw).to eq(contents)
    end
  end

end

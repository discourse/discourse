# frozen_string_literal: true

require "stringio"

RSpec.describe TopicEmbed do
  it { is_expected.to belong_to :topic }
  it { is_expected.to belong_to :post }
  it { is_expected.to validate_presence_of :embed_url }

  describe ".import" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    let(:title) { "How to turn a fish from good to evil in 30 seconds" }
    let(:url) { "http://eviltrout.com/123" }
    let(:contents) do
      "<p>hello world new post <a href='/hello'>hello</a> <img src='images/wat.jpg'></p>"
    end
    fab!(:embeddable_host)
    fab!(:category)
    fab!(:tag)

    it "returns nil when the URL is malformed" do
      expect(TopicEmbed.import(user, "invalid url", title, contents)).to eq(nil)
      expect(TopicEmbed.count).to eq(0)
    end

    it "Allows figure, figcaption, details HTML tags" do
      html = <<~HTML
        <html>
        <head>
           <title>Some title</title>
        </head>
        <body>
          <div class='content'>
            <p>some content</p>
            <figure>
              <img src="/a.png">
              <figcaption>Some caption</figcaption>
            </figure>
            <details>
              some details
            </details>
          </div>
        </body>
        </html>
      HTML

      parsed = TopicEmbed.parse_html(html, "https://blog.discourse.com/somepost.html")

      # div inception is inserted by the readability gem
      expected = <<~HTML
        <div><div>
          <div>
            <p>some content</p>
            <figure>
              <img src="https://blog.discourse.com/a.png">
              <figcaption>Some caption</figcaption>
            </figure>
            <details>
              some details
            </details>
          </div>
        </div></div>
      HTML
      expect(parsed.body.strip).to eq(expected.strip)
    end

    # ideally, articles get a heavier weightage than td elements
    # so to force that, we do not allow td elements to be scored
    it "does not score td tags" do
      html = <<~HTML
        <html>
        <head>
           <title>Some title</title>
        </head>
        <body>
          <article>
            article content
            <table>
              <tr>
                <td>
                  <p>cats</p>
                  <p>cats</p>
                </td>
              </tr>
            </table>
          </article>
        </body>
        </html>
      HTML

      parsed = TopicEmbed.parse_html(html, "https://blog.discourse.com/somepost.html")

      expected = <<-HTML
        <div><div>
  
    article content
    
      
        
          cats
          cats
        
      
    
  
</div></div>
      HTML
      expect(parsed.body.strip).to eq(expected.strip)
    end

    context "when creating a post" do
      let!(:post) { TopicEmbed.import(user, url, title, contents) }
      let(:topic_embed) { TopicEmbed.find_by(post: post) }

      it "works as expected with a new URL" do
        expect(post).to be_present

        # It uses raw_html rendering
        expect(post.cook_method).to eq(Post.cook_methods[:raw_html])
        expect(post.cooked).to eq(post.raw)

        # It converts relative URLs to absolute
        expect(post.cooked).to have_tag("a", with: { href: "http://eviltrout.com/hello" })
        expect(post.cooked).to have_tag("img", with: { src: "http://eviltrout.com/images/wat.jpg" })

        # It caches the embed content
        expect(post.topic.topic_embed.embed_content_cache).to eq(contents)

        # It converts relative URLs to absolute when expanded
        stub_request(:get, url).to_return(status: 200, body: contents)
        expect(TopicEmbed.expanded_for(post)).to have_tag(
          "img",
          with: {
            src: "http://eviltrout.com/images/wat.jpg",
          },
        )

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

      it "Supports updating the embed content cache" do
        expect do TopicEmbed.import(user, url, title, "new contents") end.to change {
          topic_embed.reload.embed_content_cache
        }
        expect(topic_embed.embed_content_cache).to eq("new contents")
      end

      it "Should leave uppercase Feed Entry URL untouched in content" do
        cased_url = "http://eviltrout.com/ABCD"
        post = TopicEmbed.import(user, cased_url, title, "some random content")
        expect(post.cooked).to match(/#{cased_url}/)
      end

      it "Should leave lowercase Feed Entry URL untouched in content" do
        cased_url = "http://eviltrout.com/abcd"
        post = TopicEmbed.import(user, cased_url, title, "some random content")
        expect(post.cooked).to match(/#{cased_url}/)
      end

      shared_examples "topic is unlisted" do
        it "unlists the topic until someone replies" do
          Jobs.run_immediately!
          imported_post =
            TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content")
          expect(imported_post.topic).not_to be_visible
          pc =
            PostCreator.new(
              Fabricate(:user),
              raw: "this is a reply that will make the topic visible",
              topic_id: imported_post.topic_id,
              reply_to_post_number: 1,
            )
          pc.create
          expect(imported_post.topic.reload).to be_visible
        end
      end

      context "when import embed unlisted is true" do
        before { SiteSetting.import_embed_unlisted = true }

        include_examples "topic is unlisted"

        context "when embed unlisted is false" do
          before { SiteSetting.embed_unlisted = false }

          include_examples "topic is unlisted"
        end
      end

      context "when import embed unlisted is false" do
        before { SiteSetting.import_embed_unlisted = false }

        context "when embed unlisted is false" do
          before { SiteSetting.embed_unlisted = false }

          it "lists the topic" do
            Jobs.run_immediately!
            imported_post =
              TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content")
            expect(imported_post.topic).to be_visible
          end
        end

        context "when embed unlisted is true" do
          before { SiteSetting.embed_unlisted = true }

          include_examples "topic is unlisted"
        end
      end

      it "creates the topic in the category passed as a parameter" do
        Jobs.run_immediately!
        imported_post =
          TopicEmbed.import(
            user,
            "http://eviltrout.com/abcd",
            title,
            "some random content",
            category_id: category.id,
          )
        expect(imported_post.topic.category).not_to eq(embeddable_host.category)
        expect(imported_post.topic.category).to eq(category)
      end

      it "does not create duplicate topics with different protocols in the embed_url" do
        Jobs.run_immediately!
        expect {
          TopicEmbed.import(user, "http://eviltrout.com/abcd", title, "some random content")
        }.to change { Topic.all.count }.by(1)

        expect {
          TopicEmbed.import(user, "https://eviltrout.com/abcd", title, "some random content")
        }.to_not change { Topic.all.count }
      end

      it "creates the topic with the tag passed as a parameter" do
        Jobs.run_immediately!
        SiteSetting.tagging_enabled = true
        imported_post =
          TopicEmbed.import(
            user,
            "http://eviltrout.com/abcd",
            title,
            "some random content",
            tags: [tag.name],
          )
        expect(imported_post.topic.tags).to include(tag)
      end

      it "respects overriding the cook_method when asked" do
        Jobs.run_immediately!
        SiteSetting.embed_support_markdown = false
        stub_request(:get, "https://www.youtube.com/watch?v=K56soYl0U1w").to_return(
          status: 200,
          body: "",
          headers: {
          },
        )
        stub_request(:get, "https://www.youtube.com/embed/K56soYl0U1w").to_return(
          status: 200,
          body: "",
          headers: {
          },
        )

        imported_post =
          TopicEmbed.import(
            user,
            "http://eviltrout.com/abcd",
            title,
            "https://www.youtube.com/watch?v=K56soYl0U1w",
            cook_method: Post.cook_methods[:regular],
          )
        expect(imported_post.cooked).to match(/onebox|iframe/)
      end

      describe "topic_embed_import_create_args modifier" do
        after { DiscoursePluginRegistry.clear_modifiers! }

        it "can alter the args used to create the topic" do
          plugin = Plugin::Instance.new
          plugin.register_modifier(:topic_embed_import_create_args) do |args|
            args[:title] = "MODIFIED: #{args[:title]}"

            args
          end

          Jobs.run_immediately!
          imported_post =
            TopicEmbed.import(
              user,
              "http://eviltrout.com/abcd",
              title,
              "some random content",
              category_id: category.id,
            )
          expect(imported_post.topic.title).to eq("MODIFIED: #{title}")
        end

        it "will revert to defaults if the modifier returns nil" do
          plugin = Plugin::Instance.new
          plugin.register_modifier(:topic_embed_import_create_args) { |args| nil }

          Jobs.run_immediately!
          imported_post =
            TopicEmbed.import(
              user,
              "http://eviltrout.com/abcd",
              title,
              "some random content",
              category_id: category.id,
            )
          expect(imported_post.topic.title).to eq(title)
        end
      end
    end

    context "when post creation supports markdown rendering" do
      before { SiteSetting.embed_support_markdown = true }

      it "works as expected" do
        post = TopicEmbed.import(user, url, title, "some random content")
        expect(post).to be_present

        # It uses regular rendering
        expect(post.cook_method).to eq(Post.cook_methods[:regular])
      end
    end

    context "when importing a topic embed with string tags" do
      fab!(:tag1) { Fabricate(:tag, name: "interesting") }
      fab!(:tag2) { Fabricate(:tag, name: "article") }
      let(:tags) { [tag1.name, tag2.name] }

      it "associates the specified tags with the existing topic" do
        imported_page = TopicEmbed.import(user, url, title, contents, tags: tags)
        expect(imported_page.topic.tags).to match_array([tag1, tag2])
      end
    end

    context "when updating an existing topic embed with string tags" do
      fab!(:tag1) { Fabricate(:tag, name: "interesting") }
      fab!(:tag2) { Fabricate(:tag, name: "article") }
      let(:tags) { [tag1, tag2] }

      before { TopicEmbed.import(user, url, title, contents, tags: [tag1.name]) }

      it "associates the specified tags with the existing topic" do
        imported_page = TopicEmbed.import(user, url, title, contents, tags: tags)
        expect(imported_page.topic.tags).to match_array([tag1, tag2])
      end

      it "does not update tags if tags are nil or unspecified" do
        imported_page = TopicEmbed.import(user, url, title, contents)
        expect(imported_page.topic.tags).to match_array([tag1])
        imported_page = TopicEmbed.import(user, url, title, contents, tags: nil)
        expect(imported_page.topic.tags).to match_array([tag1])
      end

      it "does update tags if tags are empty" do
        imported_page = TopicEmbed.import(user, url, title, contents, tags: [])
        expect(imported_page.topic.tags).to match_array([])
      end
    end

    context "with specified user and tags" do
      fab!(:tag1) { Fabricate(:tag, name: "interesting") }
      fab!(:tag2) { Fabricate(:tag, name: "article") }

      let!(:new_user) { Fabricate(:user) }
      let(:tags) { [tag1.name, tag2.name] }
      let(:imported_post) { TopicEmbed.import(new_user, url, title, contents, tags: tags) }

      it "assigns the specified user as the author" do
        expect(imported_post.user).to eq(new_user)
      end

      it "associates the specified tags with the topic" do
        expect(imported_post.topic.tags).to contain_exactly(tag1, tag2)
      end
    end

    context "when the embeddable host specifies the user and tags" do
      fab!(:tag1) { Fabricate(:tag, name: "interesting") }
      fab!(:tag2) { Fabricate(:tag, name: "article") }
      fab!(:embeddable_host) { Fabricate(:embeddable_host, host: "tag-eviltrout.com") }

      let!(:new_user) { Fabricate(:user) }
      let(:tags) { [tag1.name, tag2.name] }
      let(:embed_url_with_tags) { "http://tag-eviltrout.com/abcd" }

      let(:imported_post) do
        # passing user = system and tags = nil to ensure we're getting the user and tags from the embeddable host
        # and not from the TopicEmbed.import method in the tests
        TopicEmbed.import(Discourse.system_user, embed_url_with_tags, title, contents, tags: nil)
      end

      before do
        embeddable_host.user = new_user
        embeddable_host.tags = [tag1, tag2]
        embeddable_host.save!
      end

      it "assigns the specified user as the author" do
        expect(imported_post.user).to eq(new_user)
      end

      it "associates the specified tags with the topic" do
        expect(imported_post.topic.tags).to contain_exactly(tag1, tag2)
      end
    end

    context "when updating an existing post with new tags and a different user" do
      fab!(:tag1) { Fabricate(:tag, name: "interesting") }
      fab!(:tag2) { Fabricate(:tag, name: "article") }

      let!(:admin) { Fabricate(:admin) }
      let!(:new_admin) { Fabricate(:admin) }
      let(:tags) { [tag1.name, tag2.name] }

      before { SiteSetting.tagging_enabled = true }

      it "updates the user and adds new tags" do
        original_post = TopicEmbed.import(admin, url, title, contents)

        expect(original_post.user).to eq(admin)
        expect(original_post.topic.tags).to be_empty

        embeddable_host.update!(
          tags: [tag1, tag2],
          user: new_admin,
          category: category,
          host: "eviltrout.com",
        )

        edited_post = TopicEmbed.import(admin, url, title, contents)

        expect(edited_post.user).to eq(new_admin)
        expect(edited_post.topic.tags).to match_array([tag1, tag2])
      end
    end

    describe "embedded content truncation" do
      MAX_LENGTH_BEFORE_TRUNCATION = 100

      let(:long_content) { "<p>#{"a" * MAX_LENGTH_BEFORE_TRUNCATION}</p>\n<p>more</p>" }

      it "truncates the imported post when truncation is enabled" do
        SiteSetting.embed_truncate = true
        post = TopicEmbed.import(user, url, title, long_content)

        expect(post.raw).not_to include(long_content)
      end

      it "keeps everything in the imported post when truncation is disabled" do
        SiteSetting.embed_truncate = false
        post = TopicEmbed.import(user, url, title, long_content)

        expect(post.raw).to include(long_content)
      end

      it "looks at first div when there is no paragraph" do
        no_para = "<div><h>testing it</h></div>"

        SiteSetting.embed_truncate = true
        post = TopicEmbed.import(user, url, title, no_para)

        expect(post.raw).to include("testing it")
      end
    end
  end

  describe ".topic_id_for_embed" do
    it "returns correct topic id irrespective of url protocol" do
      topic_embed = Fabricate(:topic_embed, embed_url: "http://example.com/post/248")

      expect(TopicEmbed.topic_id_for_embed("http://exAMPle.com/post/248")).to eq(
        topic_embed.topic_id,
      )
      expect(TopicEmbed.topic_id_for_embed("https://example.com/post/248/")).to eq(
        topic_embed.topic_id,
      )

      expect(TopicEmbed.topic_id_for_embed("http://example.com/post/248/2")).to eq(nil)
      expect(TopicEmbed.topic_id_for_embed("http://examples.com/post/248")).to eq(nil)
      expect(TopicEmbed.topic_id_for_embed("http://example.com/post/24")).to eq(nil)
      expect(TopicEmbed.topic_id_for_embed("http://example.com/post")).to eq(nil)
    end

    it "finds the topic id when the embed_url contains a query string" do
      topic_embed = Fabricate(:topic_embed, embed_url: "http://example.com/post/248?key=foo")
      expect(TopicEmbed.topic_id_for_embed("http://example.com/post/248?key=foo")).to eq(
        topic_embed.topic_id,
      )
    end
  end

  describe ".find_remote" do
    fab!(:embeddable_host)

    describe ".title_scrub" do
      let(:url) { "http://eviltrout.com/123" }
      let(:contents) do
        "<title>Through the Looking Glass - Classic Books</title><body>some content here</body>"
      end

      before { stub_request(:get, url).to_return(status: 200, body: contents) }

      it "doesn't scrub the title by default" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Through the Looking Glass - Classic Books")
      end

      it "scrubs the title when the option is enabled" do
        SiteSetting.embed_title_scrubber = " - Classic Books$"
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Through the Looking Glass")
      end

      it "doesn't follow redirect when making request" do
        FinalDestination.any_instance.stubs(:resolve).returns(URI("https://redirect.com"))
        stub_request(:get, "https://redirect.com/").to_return(
          status: 301,
          body: "<title>Moved permanently</title>",
          headers: {
            "Location" => "https://www.example.org/",
          },
        )
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Moved permanently")
      end
    end

    context 'with post with allowed classes "foo" and "emoji"' do
      fab!(:user)
      let(:url) { "http://eviltrout.com/123" }
      let(:contents) do
        "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>"
      end

      before do
        SiteSetting.allowed_embed_classnames = "emoji, foo"
        stub_request(:get, url).to_return(status: 200, body: contents)
        @response = TopicEmbed.find_remote(url)
      end

      it "has no author tag" do
        expect(@response.author).to be_blank
      end

      it "img node has emoji class" do
        expect(@response.body).to have_tag("img", with: { class: "emoji" })
      end

      it "img node has foo class" do
        expect(@response.body).to have_tag("img", with: { class: "foo" })
      end

      it "p node has foo class" do
        expect(@response.body).to have_tag("p", with: { class: "foo" })
      end

      it "nodes removes classes other than emoji" do
        expect(@response.body).to have_tag("img", without: { class: "other" })
      end
    end

    context "with post with author metadata" do
      fab!(:user) { Fabricate(:user, username: "eviltrout") }
      let(:url) { "http://eviltrout.com/321" }
      let(:contents) do
        '<html><head><meta name="author" content="eviltrout"></head><body>rich and morty</body></html>'
      end

      before(:each) { stub_request(:get, url).to_return(status: 200, body: contents) }

      it "has no author tag" do
        response = TopicEmbed.find_remote(url)

        expect(response.author).to eq(user)
      end
    end

    context "with post with no allowed classes" do
      fab!(:user)
      let(:url) { "http://eviltrout.com/123" }
      let(:contents) do
        "my normal size emoji <p class='foo'>Hi</p> <img class='emoji other foo' src='/images/smiley.jpg'>"
      end

      before(:each) do
        SiteSetting.allowed_embed_classnames = ""
        stub_request(:get, url).to_return(status: 200, body: contents)
        @response = TopicEmbed.find_remote(url)
      end

      it 'img node doesn\'t have emoji class' do
        expect(@response.body).to have_tag("img", without: { class: "emoji" })
      end

      it 'img node doesn\'t have foo class' do
        expect(@response.body).to have_tag("img", without: { class: "foo" })
      end

      it 'p node doesn\'t foo class' do
        expect(@response.body).to have_tag("p", without: { class: "foo" })
      end

      it 'img node doesn\'t have other class' do
        expect(@response.body).to have_tag("img", without: { class: "other" })
      end
    end

    context "with non-ascii URL" do
      let(:url) { "http://eviltrout.com/test/ماهی" }
      let(:contents) { "<title>سلام</title><body>این یک پاراگراف آزمون است.</body>" }

      before { stub_request(:get, url).to_return(status: 200, body: contents) }

      it "doesn't throw an error" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("سلام")
      end
    end

    context "with encoded URL" do
      let(:url) { "http://example.com/hello%20world" }
      let(:contents) { "<title>Hello World!</title><body></body>" }

      before { stub_request(:get, url).to_return(status: 200, body: contents) }

      it "doesn't throw an error" do
        response = TopicEmbed.find_remote(url)
        expect(response.title).to eq("Hello World!")
      end
    end

    context "with non-http URL" do
      it "throws an error" do
        url = "/test.txt"

        expect(TopicEmbed.find_remote(url)).to be_nil
      end
    end

    context "with emails" do
      let(:url) { "http://example.com/foo" }
      let(:contents) do
        '<p><a href="mailto:foo%40example.com">URL encoded @ symbol</a></p><p><a href="mailto:bar@example.com">normal mailto link</a></p>'
      end

      before { stub_request(:get, url).to_return(status: 200, body: contents) }

      it "handles mailto links" do
        response = TopicEmbed.find_remote(url)

        expect(response.body).to have_tag("a", with: { href: "mailto:foo@example.com" })
        expect(response.body).to have_tag("a", with: { href: "mailto:bar@example.com" })
      end
    end

    context "with malformed href" do
      let(:url) { "http://example.com/foo" }
      let(:contents) { '<p><a href="(http://foo.bar)">Baz</a></p>' }

      before { stub_request(:get, url).to_return(status: 200, body: contents) }

      it "doesn’t raise an exception" do
        expect { TopicEmbed.find_remote(url) }.not_to raise_error
      end
    end

    context "with canonical links" do
      fab!(:user)
      let(:title) { "How to turn a fish from good to evil in 30 seconds" }
      let(:url) { "http://eviltrout.com/123?asd" }
      let(:canonical_url) { "http://eviltrout.com/123" }
      let(:url2) { "http://eviltrout.com/blog?post=1&canonical=false" }
      let(:canonical_url2) { "http://eviltrout.com/blog?post=1" }
      let(:content) { "<head><link rel=\"canonical\" href=\"#{canonical_url}\"></head>" }
      let(:content2) { "<head><link rel=\"canonical\" href=\"#{canonical_url2}\"></head>" }
      let(:canonical_content) { "<title>Canonical</title><body></body>" }

      before do
        stub_request(:get, url).to_return(status: 200, body: content)
        stub_request(:head, canonical_url)
        stub_request(:get, canonical_url).to_return(status: 200, body: canonical_content)

        stub_request(:get, url2).to_return(status: 200, body: content2)
        stub_request(:head, canonical_url2)
        stub_request(:get, canonical_url2).to_return(status: 200, body: canonical_content)
      end

      it "fetches canonical content" do
        response = TopicEmbed.find_remote(url)

        expect(response.title).to eq("Canonical")
        expect(response.url).to eq(canonical_url)
      end

      it "does not create duplicate topics when url differs from canonical_url" do
        Jobs.run_immediately!
        expect { TopicEmbed.import_remote(canonical_url, { title: title, user: user }) }.to change {
          Topic.all.count
        }.by(1)

        expect { TopicEmbed.import_remote(url, { title: title, user: user }) }.to_not change {
          Topic.all.count
        }
      end

      it "does not create duplicate topics when url contains extra params" do
        Jobs.run_immediately!
        expect {
          TopicEmbed.import_remote(canonical_url2, { title: title, user: user })
        }.to change { Topic.all.count }.by(1)

        expect { TopicEmbed.import_remote(url2, { title: title, user: user }) }.to_not change {
          Topic.all.count
        }
      end
    end
  end

  describe ".absolutize_urls" do
    it "handles badly formed URIs" do
      invalid_url = "http://source.com/#double#anchor"
      contents = "hello world new post <a href='/hello'>hello</a>"

      raw = TopicEmbed.absolutize_urls(invalid_url, contents)
      expect(raw).to eq("hello world new post <a href=\"http://source.com/hello\">hello</a>")
    end

    it "handles malformed links" do
      url = "https://somesource.com"

      contents = <<~HTML
        hello world new post <a href="mailto:somemail@somewhere.org>">hello</a>
        some image <img src="https:/><invalidimagesrc/">
      HTML

      raw = TopicEmbed.absolutize_urls(url, contents)
      expect(raw).to eq(contents)
    end
  end

  describe ".imported_from_html" do
    after { I18n.reload! }

    it "uses the default site locale for the 'imported_from' footer" do
      TranslationOverride.upsert!(
        "en",
        "embed.imported_from",
        "English translation of embed.imported_from with %{link}",
      )
      TranslationOverride.upsert!(
        "de",
        "embed.imported_from",
        "German translation of embed.imported_from with %{link}",
      )

      I18n.locale = :en
      expected_html = TopicEmbed.imported_from_html("some_url")

      I18n.locale = :de
      expect(TopicEmbed.imported_from_html("some_url")).to eq(expected_html)
    end

    it "normalize_encodes the url" do
      html =
        TopicEmbed.imported_from_html(
          'http://www.discourse.org/%23<%2Fa><img%20src%3Dx%20onerror%3Dalert("document.domain")%3B>',
        )
      expected_html =
        "\n<hr>\n<small>This is a companion discussion topic for the original entry at <a href='http://www.discourse.org/%23%3C/a%3E%3Cimg%20src=x%20onerror=alert(%22document.domain%22);%3E'>http://www.discourse.org/%23%3C/a%3E%3Cimg%20src=x%20onerror=alert(%22document.domain%22);%3E</a></small>\n"
      expect(html).to eq(expected_html)
    end
  end

  describe ".expanded_for" do
    fab!(:user)
    let(:title) { "How to turn a fish from good to evil in 30 seconds" }
    let(:url) { "http://eviltrout.com/123" }
    let(:contents) { "<p>hello world new post :D</p>" }
    fab!(:embeddable_host)
    fab!(:category)
    fab!(:tag)

    it "returns embed content" do
      stub_request(:get, url).to_return(status: 200, body: contents)
      post = TopicEmbed.import(user, url, title, contents)
      expect(TopicEmbed.expanded_for(post)).to include(contents)
    end

    it "updates the embed content cache" do
      stub_request(:get, url)
        .to_return(status: 200, body: contents)
        .then
        .to_return(status: 200, body: "contents changed")
      post = TopicEmbed.import(user, url, title, contents)
      TopicEmbed.expanded_for(post)
      expect(post.topic.topic_embed.reload.embed_content_cache).to include("contents changed")
    end
  end
end

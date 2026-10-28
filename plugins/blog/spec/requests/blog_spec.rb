# frozen_string_literal: true

RSpec.describe "Blog publication", type: :request do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) do
    Fabricate(
      :post,
      topic: topic,
      user: admin,
      raw: "A private article that is not yet ready for the world.",
    )
  end

  before { enable_blog!(category: category, drafts: drafts) }

  describe "GET /blog/editor.json" do
    it "requires staff access" do
      get "/blog/editor.json"
      expect(response.status).to eq(403)
      sign_in(user)
      get "/blog/editor.json"
      expect(response.status).to eq(403)
    end

    it "keeps the editor reachable when the blog origin is misconfigured as Discuss" do
      SiteSetting.blog_url = "https://test.localhost"
      sign_in(admin)
      get "/blog/editor.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("blog.errors.origin"))
    end

    it "renders an anonymous login shell without exposing draft data" do
      get "/blog/editor"
      expect(response.status).to eq(200)
      expect(response.body).not_to include(topic.title)
      get "/blog/editor.json"
      expect(response.status).to eq(403)
    end

    it "reports anonymous upload restrictions without exposing the public blog" do
      publication = Blog::Publication.for_topic(topic)
      publication.publish!(admin)
      SiteSetting.prevent_anons_from_downloading_files = true

      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
      expect(publication.reload).not_to be_publicly_visible

      get "https://test.localhost/session/#{admin.encoded_username}/become"
      get "https://test.localhost/blog/editor.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).to eq(I18n.t("blog.errors.anonymous_uploads"))

      post "https://test.localhost/blog/publications/#{topic.id}/publish.json"
      expect(response.status).to eq(400)
    end

    it "lists only editorial topics" do
      Fabricate(:topic)
      sign_in(admin)
      get "/blog/editor.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to contain_exactly(
        topic.id,
      )
      expect(response.parsed_body["error"]).to be_nil
    end
  end

  describe "PUT /blog/publications/:topic_id" do
    before { sign_in(admin) }

    it "rejects paths reserved by routing" do
      %w[/sitemap /images/story /font/story /plugins/story /about].each do |path|
        put "/blog/publications/#{topic.id}.json", params: { publication: { path: path } }
        expect(response.status).to eq(422)
      end
      expect(Blog::Publication.where(topic_id: topic.id)).not_to exist
    end

    it "rejects null metadata and invalid dates without a database error" do
      [
        { excerpt: nil },
        { featured: nil },
        { published_at: "not-a-date" },
        { published_at: 1.day.from_now.iso8601 },
      ].each do |attributes|
        put "/blog/publications/#{topic.id}.json", params: { publication: attributes }, as: :json
        expect(response.status).to eq(422)
      end
    end

    it "rejects drafts categories that ordinary groups can read" do
      group = Fabricate(:group)
      drafts.set_permissions(group.name => :full, :staff => :full)
      drafts.save!
      put "/blog/publications/#{topic.id}.json", params: { publication: { excerpt: "A draft" } }
      expect(response.status).to eq(400)
      expect(Blog::Publication.where(topic_id: topic.id)).not_to exist
    end
  end

  describe "GET /blog/preview/:topic_id" do
    it "allows a staff-only uncached preview without publishing" do
      design =
        Blog::BlogTheme.save(
          {
            "name" => "Spec design",
            "accent_color" => "d64b2a",
            "paper_color" => "f5f0e6",
            "ink_color" => "19382d",
            "css" => "",
            "javascript" => "window.blogOnly = true;",
          },
          user: admin,
        )
      Blog::BlogTheme.activate(design["id"], revision: 1, user: admin)

      get "/blog/preview/#{topic.id}"
      expect(response.status).to eq(404)
      sign_in(admin)
      get "/blog/preview/#{topic.id}"
      expect(response.status).to eq(200)
      expect(response.body).to include(first_post.cooked)
      expect(Nokogiri.HTML5(response.body).at_css("script[data-blog-custom-script]")).to be_nil
      expect(response.headers["X-Robots-Tag"]).to include("noindex")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(Blog::Publication.where(topic_id: topic.id)).not_to exist
      expect(topic.reload.category_id).to eq(drafts.id)
    end
  end

  describe "POST /blog/publications/:topic_id/publish" do
    it "publishes a private draft, serves it on the blog host, and preserves the discussion" do
      sign_in(admin)
      put "/blog/publications/#{topic.id}.json",
          params: {
            publication: {
              path: "/first-story",
              excerpt: "A careful introduction",
            },
          }
      expect(response.status).to eq(200)
      post "/blog/publications/#{topic.id}/submit.json"
      expect(response.status).to eq(200)
      revision_id = response.parsed_body.dig("submitted_revision", "id")
      post "/blog/publications/#{topic.id}/approve.json", params: { revision_id: revision_id }
      expect(response.status).to eq(200)
      post "/blog/publications/#{topic.id}/publish.json", params: { revision_id: revision_id }
      expect(response.status).to eq(200)
      publication = Blog::Publication.find_by!(topic_id: topic.id)
      expect(publication.discussion_topic.reload.category_id).to eq(category.id)
      expect(publication).to be_publicly_visible
      expect(TopicView.new(publication.discussion_topic_id).canonical_path).to eq(publication.url)

      get "https://blog.example.com/first-story"
      expect(response.status).to eq(200)
      html = Nokogiri.HTML5(response.body)
      expect(html.at_css('link[rel="canonical"]')["href"]).to eq(publication.url)
      expect(html.at_css("#discourse-comments")["data-topic-id"]).to eq(
        publication.discussion_topic_id.to_s,
      )
      expect(html.at_css(".blog-article__body").text).to include(first_post.raw)
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "rejects unrelated topics and normal users" do
      sign_in(admin)
      other_topic = Fabricate(:topic)
      post "/blog/publications/#{other_topic.id}/publish.json"
      expect(response.status).to eq(403)
      sign_in(user)
      post "/blog/publications/#{topic.id}/publish.json"
      expect(response.status).to eq(403)
      expect(topic.reload.category_id).to eq(drafts.id)
    end

    it "fails closed when the draft category is public" do
      SiteSetting.blog_drafts_category = category.id
      sign_in(admin)
      post "/blog/publications/#{topic.id}/publish.json"
      expect(response.status).to eq(403)
      expect(topic.reload.category_id).to eq(drafts.id)
    end
  end

  describe "GET blog articles and feeds" do
    let!(:publication) do
      publication = Blog::Publication.for_topic(topic)
      publication.path = "/private-to-public"
      publication.publish!(admin)
      publication
    end

    it "preserves historical canonical paths through publishing and corrections" do
      paths = %w[
        /archive/2011/03/30/How+I+learned+to+write+my+own+ORM
        /archive/2009/01/02/My+server+just+died%2C+long+live+my+new+VPS
        /archive/2008/06/06/video_browser_past_present_and_future
        /archive/2011/09/08/Extending+the+ASP.NET+error+page
        /blog/archive/2007/02/16/7.aspx
      ]
      previous_url = publication.url

      paths.each do |path|
        publication.save_metadata!(admin, path: path)
        publication.publish!(admin)

        get "https://blog.example.com#{path}"
        expect(response.status).to eq(200)
        html = Nokogiri.HTML5(response.body)
        expect(html.at_css('link[rel="canonical"]')["href"]).to eq(
          "https://blog.example.com#{path}",
        )
        expect(html.at_css(".blog-article__body").text).to include(first_post.raw)
        expect(html.at_css("#discussion #comments")).to be_present

        get previous_url
        expect(response).to redirect_to("https://blog.example.com#{path}")
        expect(response.status).to eq(301)
        previous_url = publication.url
      end

      publication.unpublish!(admin)
      paths.each do |path|
        get "https://blog.example.com#{path}"
        expect(response.status).to eq(404)
      end
    end

    it "permanently redirects legacy index and feed endpoints on the blog host" do
      {
        "/posts" => "/",
        "/posts.rss" => "/feed.xml",
        "/posts.atom" => "/feed.xml",
      }.each do |path, target|
        get "https://blog.example.com#{path}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to("https://blog.example.com#{target}")
      end
    end

    it "preserves the configured blog host when it is not a database hostname alias" do
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(["test.localhost"])

      get "https://blog.example.com#{publication.path}",
          headers: {
            "X-Forwarded-Host" => "untrusted.example.com",
          }

      expect(request.env["HTTP_HOST"]).to eq("blog.example.com")
      expect(request.env["HTTP_X_FORWARDED_HOST"]).to be_nil
      expect(response.status).to eq(200)
      expect(response.body).to include(publication.url)
    end

    it "supports an explicit default port and rejects other ports" do
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(["test.localhost"])

      get publication.path, headers: { "Host" => "blog.example.com:443" }
      expect(request.env["HTTP_HOST"]).to eq("blog.example.com:443")
      expect(response.body).to include(publication.url)

      get publication.path, headers: { "Host" => "blog.example.com:444" }
      expect(request.env["HTTP_HOST"]).to eq("test.localhost")
      expect(response.body).not_to include(publication.url)
    end

    it "continues rewriting untrusted hosts to the discussion host" do
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(["test.localhost"])

      get "https://untrusted.example.com#{publication.path}",
          headers: {
            "X-Forwarded-Host" => "blog.example.com",
          }

      expect(request.env["HTTP_HOST"]).to eq("test.localhost")
      expect(request.env["HTTP_X_FORWARDED_HOST"]).to be_nil
      expect(response.body).not_to include(publication.url)
    end

    it "exposes only published articles across the homepage, archive, feed and sitemap" do
      unpublished = Fabricate(:topic, category: category)
      %w[/ /archive /feed.xml /sitemap.xml].each do |path|
        get "https://blog.example.com#{path}"
        expect(response.status).to eq(200)
        expect(response.body).to include(publication.url)
        expect(response.body).not_to include(unpublished.title)
      end
    end

    it "serves robots, the About page, and tag pages from the same published set" do
      SiteSetting.blog_about = "We publish **field notes** from the team."
      DiscourseTagging.tag_topic_by_names(
        publication.discussion_topic,
        Guardian.new(admin),
        ["field-notes"],
      )

      get "https://blog.example.com/robots.txt"
      expect(response.status).to eq(200)
      expect(response.body).to include("Sitemap: https://blog.example.com/sitemap.xml")

      get "https://blog.example.com/about"
      expect(response.status).to eq(200)
      expect(response.body).to include("<strong>field notes</strong>")
      expect(response.body).not_to include(publication.url)

      get "https://blog.example.com/tag/field-notes"
      expect(response.status).to eq(200)
      expect(response.body).to include(publication.url)

      get "https://blog.example.com/tag/some-other-tag"
      expect(response.status).to eq(404)
    end

    it "leads the homepage with featured articles" do
      featured_topic = Fabricate(:topic, category: drafts, user: admin)
      Fabricate(
        :post,
        topic: featured_topic,
        user: admin,
        raw: "A featured story for the homepage.",
      )
      featured = Blog::Publication.for_topic(featured_topic)
      featured.path = "/featured-story"
      featured.save_metadata!(admin, featured: true)
      featured.publish!(admin)

      get "https://blog.example.com/"

      expect(response.status).to eq(200)
      body = response.body
      expect(body.index(featured.url)).to be < body.index(publication.url)
      expect(body).to include("<span class=\"blog__badge\">#{I18n.t("blog.featured")}</span>")
    end

    it "withdraws all public surfaces immediately when the category becomes private" do
      publication.discussion_topic.update!(category: drafts)
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
      %w[/ /feed.xml /sitemap.xml].each do |path|
        get "https://blog.example.com#{path}"
        expect(response.body).not_to include(topic.title)
      end
      expect(TopicView.new(topic.id, admin).canonical_path).not_to eq(publication.url)
    end

    it "withdraws a hidden or deleted first post even for an editor" do
      sign_in(admin)
      publication.discussion_topic.first_post.update!(hidden: true)
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
      publication.discussion_topic.first_post.update!(hidden: false, deleted_at: Time.current)
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
    end

    it "does not publish topics from subcategories" do
      child = Fabricate(:category, parent_category: category)
      publication.discussion_topic.update!(category: child)
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
    end

    it "retains old article paths as redirects and prevents taking another article path" do
      publication.save_metadata!(admin, path: "/renamed-story")
      publication.publish!(admin)
      get "https://blog.example.com/private-to-public"
      expect(response.status).to eq(301)
      expect(response.location).to eq(publication.url)
      host! "test.localhost"
      another = Fabricate(:topic, category: drafts)
      Fabricate(:post, topic: another)
      sign_in(admin)
      put "/blog/publications/#{another.id}.json",
          params: {
            publication: {
              path: "/private-to-public",
            },
          }
      expect(response.status).to eq(422)
    end

    it "keeps later draft edits private until an approved revision is published" do
      topic.update!(title: "An article with <script>alert(1)</script>")
      first_post.revise(admin, raw: "An updated article, now ready for everyone to read.")
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(200)
      html = Nokogiri.HTML5(response.body)
      expect(html.at_css(".blog-article__body").text).not_to include(first_post.reload.raw)
      publication.publish!(admin)
      get "https://blog.example.com#{publication.path}"
      html = Nokogiri.HTML5(response.body)
      expect(html.at_css(".blog-article__body").text).to include(first_post.raw)
      expect(html.css("h1 script")).to be_empty
    end

    it "supports stable dated paths, title search, and empty feeds" do
      publication.save_metadata!(admin, path: "/archive/2026/09/08/a-story")
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(200)
      get "https://blog.example.com/archive", params: { q: topic.title }
      expect(response.status).to eq(200)
      expect(response.body).to include(publication.url)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      publication.unpublish!(admin)
      get "https://blog.example.com/feed.xml"
      expect(response.status).to eq(200)
      expect(Nokogiri.XML(response.body).xpath("//item")).to be_empty
    end

    it "keeps core shared drafts private even if moved into the blog category" do
      SharedDraft.create!(topic: publication.discussion_topic, category: category)
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
      expect(response.body).not_to include(topic.title)
    end

    it "avoids prompting for the first reply on a closed empty discussion" do
      publication.discussion_topic.update!(closed: true)
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(200)
      expect(response.body).to include(I18n.t("blog.discussion_closed"))
      expect(Nokogiri.HTML5(response.body).at_css("#discourse-comments")).to be_nil
    end

    it "preserves page-specific discussion canonicals" do
      expect(TopicView.new(publication.discussion_topic_id, nil, page: 2).canonical_path).not_to eq(
        publication.url,
      )
      get publication.discussion_topic.relative_url
      expect(response.status).to eq(200)
      expect(Nokogiri.HTML5(response.body).at_css('link[rel="canonical"]')["href"]).to eq(
        publication.url,
      )
    end

    it "keeps drafts off normal anonymous discussion endpoints" do
      topic.update!(category: drafts)
      get "/t/#{topic.slug}/#{topic.id}.json"
      expect(response.status).to eq(404)
      get "/latest.json"
      expect(
        response.parsed_body["topic_list"]["topics"].map { |entry| entry["id"] },
      ).not_to include(topic.id)
    end

    it "keeps core routes on the discussion host" do
      get "/about.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to have_key("about")
      get "/blog/editor.json"
      expect(response.status).to eq(403)
      get "https://blog.example.com/blog/editor.json"
      expect(response.status).to eq(404)
    end

    it "fails closed on private sites and secure uploads" do
      setup_s3
      SiteSetting.secure_uploads = true
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
      expect(publication.reload).not_to be_publicly_visible
    end
  end

  describe "DELETE /blog/publications/:topic_id" do
    it "withdraws the blog without privatizing the discussion" do
      publication = Blog::Publication.for_topic(topic)
      publication.publish!(admin)
      sign_in(admin)
      delete "/blog/publications/#{topic.id}.json"
      expect(response.status).to eq(204)
      expect(publication.discussion_topic.reload.category_id).to eq(category.id)
      expect(publication.reload).not_to be_publicly_visible
      expect(TopicView.new(publication.discussion_topic_id).canonical_path).not_to eq(
        publication.url,
      )
      get "https://blog.example.com#{publication.path}"
      expect(response.status).to eq(404)
    end
  end

  describe "POST /blog/publications/:topic_id/return-to-drafts" do
    it "returns an article without replies to private drafts" do
      publication = Blog::Publication.for_topic(topic)
      publication.publish!(admin)
      sign_in(admin)
      post "/blog/publications/#{topic.id}/return-to-drafts.json"
      expect(response.status).to eq(204)
      expect(topic.reload.category_id).to eq(drafts.id)
      expect(publication.reload).not_to be_published
    end

    it "preserves public access to other people's replies" do
      publication = Blog::Publication.for_topic(topic)
      publication.publish!(admin)
      reply = Fabricate(:post, topic: publication.discussion_topic, user: user)
      sign_in(admin)
      post "/blog/publications/#{topic.id}/return-to-drafts.json"
      expect(response.status).to eq(204)
      expect(publication.discussion_topic.reload.category_id).to eq(category.id)
      expect(reply.reload.topic_id).to eq(publication.discussion_topic_id)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Markdown endpoints" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:category)
  fab!(:topic) do
    Fabricate(:topic, user: user, category: category, title: "Markdown endpoint topic")
  end
  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "Visible body") }

  after { category.clear_url_cache }

  it "respects the upcoming change promotion policy and explicit opt-in" do
    SiteSetting.promote_upcoming_changes_on_status = "stable"

    get "/latest.md"
    expect(response).to have_http_status(:not_found)

    get "/latest", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to be_blank

    SiteSetting.enable_markdown_endpoints = true

    get "/latest.md"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")

    get "/latest", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to include("/latest.md")
  end

  it "keeps HTML tag-intersection redirects out of Markdown routes" do
    tag = Fabricate(:tag)

    [false, true].each do |enabled|
      SiteSetting.enable_markdown_endpoints = enabled
      get "/tags/intersection/#{tag.name}/#{tag.name}", headers: { "ACCEPT" => "text/html" }
      expect(response).to redirect_to("/tag/#{tag.name}")
      follow_redirect!
      expect(response).to redirect_to(tag.url)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
    end
  end

  def vary_tokens
    response.headers.fetch("Vary", "").split(",").map(&:strip)
  end

  it "converts emoji in topic headings and list links while preserving Markdown escaping" do
    topic.update_columns(title: "Emoji [demo] :smile: :wave:t4: :thumbsup:t6: :custom_emoji:")
    title = "Emoji \\[demo\\] 😄 👋🏽 👍🏿 :custom\\_emoji:"

    get "/t/#{topic.slug}/#{topic.id}.md"

    expect(response).to have_http_status(:ok)
    expect(response.body).to start_with("# #{title}\n")

    get "/latest.md"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("## [#{title}](#{topic.url})")
  end

  it "serves latest topics for Markdown requests to the homepage" do
    get "/", headers: { "ACCEPT" => "text/markdown" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include(topic.title, "**URL:** #{Discourse.base_url}/latest.md")
    expect(vary_tokens).to include("Accept")

    head "/", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to be_empty

    get "/.md"
    expect(response).to have_http_status(:not_found)
  end

  it "preserves the configured HTML homepage and advertises latest Markdown" do
    Fabricate(:admin)
    SiteSetting.top_menu = "categories|latest|hot|top"

    [
      "text/html",
      "*/*",
      "text/markdown;q=0, text/html",
      "text/markdown, text/html",
    ].each do |accept|
      get "/", headers: { "ACCEPT" => accept }

      expect(response).to have_http_status(:ok), accept
      expect(response.media_type).to eq("text/html")
      expect(controller.controller_name).to eq("categories")
      expect(response.headers["Link"]).to include("#{Discourse.base_url}/latest.md")
      expect(response.body).to include('type="text/markdown"', "/latest.md")
      expect(vary_tokens).to include("Accept")
    end

    get "/", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to start_with("# Latest")
  end

  it "adds Vary: Accept to negotiated responses and redirects" do
    [
      %w[text/html text/html],
      %w[application/json application/json],
      %w[text/markdown text/markdown],
    ].each do |accept, media_type|
      get "/t/#{topic.slug}/#{topic.id}", headers: { "ACCEPT" => accept }

      expect(response.media_type).to eq(media_type)
      expect(vary_tokens.grep(/\Aaccept\z/i).length).to eq(1)
    end

    get "/t/#{topic.id}", headers: { "ACCEPT" => "text/markdown" }
    expect(response).to have_http_status(:moved_permanently)
    expect(vary_tokens.grep(/\Aaccept\z/i).length).to eq(1)

    get "/t/#{topic.slug}/#{topic.id}/999", headers: { "ACCEPT" => "text/markdown" }
    expect(response).to have_http_status(:not_found)
    expect(vary_tokens.grep(/\Aaccept\z/i).length).to eq(1)
  end

  it "preserves explicit Markdown when redirecting an out-of-range topic page" do
    2.upto(TopicView::CHUNK_SIZE + 1) do |post_number|
      Fabricate(:post, topic:, user:, post_number:)
    end

    get "/t/#{topic.slug}/#{topic.id}.md?page=999"
    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to end_with(".md?page=2")
    follow_redirect!
    expect(response.media_type).to eq("text/markdown")

    get "/t/#{topic.slug}/#{topic.id}.json?page=999"
    expect(response.location).to end_with(".json?page=2")

    get "/t/#{topic.slug}/#{topic.id}?page=999", headers: { "ACCEPT" => "text/html" }
    expect(response.location).to end_with("/#{topic.id}?page=2")
  end

  it "supports suffix and Accept negotiation without overriding HTML, JSON, or RSS" do
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("# Markdown endpoint topic", post.raw)
    expect(response.headers["Vary"].split(",").map(&:strip)).to include("Accept")

    get "/t/#{topic.slug}/#{topic.id}",
        headers: {
          "ACCEPT" => "text/markdown;q=0.9, text/html;q=0.8",
        }
    expect(response.media_type).to eq("text/markdown")

    get "/t/#{topic.id}", headers: { "ACCEPT" => "text/markdown" }
    expect(response.location).to end_with(".md")
    follow_redirect!
    expect(response.media_type).to eq("text/markdown")

    get "/t/#{topic.slug}/#{topic.id}", headers: { "ACCEPT" => "text/markdown, text/html" }
    expect(response.media_type).to eq("text/html")

    get "/t/#{topic.slug}/#{topic.id}",
        headers: {
          "ACCEPT" => "text/markdown;q=0.8, application/json;q=0.9",
        }
    expect(response.media_type).to eq("application/json")

    get "/t/#{topic.slug}/#{topic.id}.json", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).to eq("application/json")

    get "/t/#{topic.slug}/#{topic.id}.rss", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).to eq("application/rss+xml")
  end

  it "preserves explicit formats and unrelated topic and category routes" do
    tag = Fabricate(:tag)
    topic.tags << tag

    [
      "/t/#{topic.slug}/#{topic.id}.json",
      "/t/#{topic.slug}/#{topic.id}.rss",
      "/c/#{category.slug}/#{category.id}.json",
      "/c/#{category.slug}/#{category.id}.rss",
      "/tag/#{tag.slug_for_url}/#{tag.id}.json",
      "/tag/#{tag.slug_for_url}/#{tag.id}.rss",
      "/t/#{topic.id}/posts",
      "/t/#{topic.id}/post_ids",
    ].each do |path|
      get path, headers: { "ACCEPT" => "text/markdown" }
      expect(response.media_type).not_to eq("text/markdown"), path
    end

    get "/about", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).not_to eq("text/markdown")

    get "/c/#{category.slug}/#{category.id}/subcategories", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).not_to eq("text/markdown")
  end

  it "limits Markdown and discovery to the supported routes" do
    tag = Fabricate(:tag)
    paths = [
      "/unseen",
      "/bookmarks",
      "/top/yearly",
      "/c/#{category.slug}/#{category.id}/none",
      "/c/#{category.slug}/#{category.id}/l/latest",
      "/tag/#{tag.slug_for_url}/#{tag.id}/l/latest",
      "/u/#{user.username}/activity",
    ]

    paths.each do |path|
      get "#{path}.md"
      expect(response).to have_http_status(:not_found), path

      get path, headers: { "ACCEPT" => "text/markdown" }
      expect(response.media_type).not_to eq("text/markdown"), path
      expect(response.headers["Link"]).to be_blank, path

      get path, headers: { "ACCEPT" => "text/html" }
      expect(response.headers["Link"]).to be_blank, path
      expect(response.body).not_to include('type="text/markdown"'), path
    end
  end

  it "lets the explicit suffix win and handles HEAD and invalid posts" do
    get "/t/#{topic.slug}/#{topic.id}.md", headers: { "ACCEPT" => "application/json" }
    expect(response.media_type).to eq("text/markdown")

    head "/t/#{topic.slug}/#{topic.id}.md"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to be_empty

    head "/latest.md"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to be_empty

    get "/t/#{topic.slug}/#{topic.id}/999.md"
    expect(response).to have_http_status(:not_found)
  end

  it "separates topic metadata rows with hard line breaks" do
    SiteSetting.tagging_enabled = true
    topic.tags << Fabricate(:tag)

    ["/t/#{topic.slug}/#{topic.id}.md", "/t/#{topic.slug}/#{topic.id}/1.md"].each do |path|
      get path

      expect(response).to have_http_status(:ok)
      heading, metadata = response.body.split("\n\n", 3)
      expect(heading).to eq("# #{topic.title}")
      rows = metadata.lines.map(&:chomp)
      expect(rows.map { |row| row[/\A\*\*(.+):\*\*/, 1] }).to eq(
        [
          "URL",
          "Category",
          "Tags",
          "Created",
          "Posts on this page",
          path.end_with?("/1.md") ? "Showing post" : "Page",
        ],
      )
      expect(rows[0...-1]).to all(end_with("\\"))
      expect(rows.last).to eq(path.end_with?("/1.md") ? "**Showing post:** 1" : "**Page:** 1")
      expect(rows.first).to eq("**URL:** <#{topic.url}>\\")
      rendered_metadata = Nokogiri::HTML5.fragment(PrettyText.cook(metadata))
      expect(rendered_metadata.at_css("a")["href"]).to eq(topic.url)
    end
  end

  it "paginates rendered posts with translated Markdown navigation links" do
    TranslationOverride.upsert!("en", "markdown_endpoints.previous_page", "Earlier posts")
    TranslationOverride.upsert!("en", "markdown_endpoints.next_page", "Later posts")
    replies =
      2
        .upto(TopicView::CHUNK_SIZE + 1)
        .map do |post_number|
          Fabricate(:post, topic:, user:, post_number:, raw: "Reply #{post_number}")
        end

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(
      post.raw,
      "**Page:** 1",
      "[Later posts](#{topic.url}.md?page=2)",
    )
    expect(response.body).not_to include(replies.last.raw)

    get "/t/#{topic.slug}/#{topic.id}.md?page=2"
    expect(response.body).to include(
      replies.last.raw,
      "**Page:** 2",
      "[Earlier posts](#{topic.url}.md?page=1)",
    )
    expect(response.body).not_to include(post.raw, "[Later posts]")
  end

  it "renders just the requested post" do
    reply = Fabricate(:post, topic:, user:, raw: "Reply body")

    get "/t/#{topic.slug}/#{topic.id}/#{reply.post_number}.md"
    expect(response.body).to include(
      reply.raw,
      "**Showing post:** #{reply.post_number}",
      "View the full topic",
    )
    expect(response.body).not_to include(post.raw, "[Next page]", "[Previous page]")
  end

  it "links topic and post authors to subfolder-safe user profiles" do
    set_subfolder "/forum"
    SiteSetting.external_system_avatars_url = ""
    author = Fabricate(:user, username: "reply_author")
    reply = Fabricate(:post, topic: topic, user: author)

    get "/latest.md"
    expect(response.body).to include(
      "**Author:** [@#{user.username}](#{Discourse.base_url}/u/#{user.encoded_username})",
    )
    expect(response.body).not_to include("![")

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(
      "[@#{user.username}](#{Discourse.base_url}/u/#{user.encoded_username})",
      "**Author:** ![reply\\_author](#{Discourse.base_url}/letter_avatar/reply_author/32/#{LetterAvatar.version}.png) [@reply\\_author](#{Discourse.base_url}/u/#{author.encoded_username})",
      "\n**Post date:** ",
    )

    get "/t/#{topic.slug}/#{topic.id}/#{reply.post_number}.md"
    expect(response.body).to include(
      "[@reply\\_author](#{Discourse.base_url}/u/#{author.encoded_username})",
    )

    reply.update_columns(user_id: nil)
    get "/t/#{topic.slug}/#{topic.id}/#{reply.post_number}.md"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("**Post date:** ")
    expect(response.body).not_to include("**Author:**")
  end

  it "wraps list metadata separately from titles and excerpts with Markdown block boundaries" do
    topic.update!(excerpt: "An excerpt outside metadata", last_posted_at: post.created_at)

    get "/latest.md"

    metadata = response.body.scan(%r{<div class="topic-metadata">\n\n(.*?)\n\n</div>}m)
    expect(metadata.size).to eq(1)
    expect(metadata.first.first).to include("**Author:**", "**Replies:**", "**Last updated:**")
    expect(metadata.first.first).to include("\\\n**Replies:**", "\\\n**Last updated:**")
    expect(metadata.first.first).not_to include(topic.title, topic.excerpt)
    expect(response.body).to include(
      "## [#{topic.title}](#{topic.url})\n\n<div class=\"topic-metadata\">",
      "</div>\n\n#{topic.excerpt}",
    )
  end

  it "wraps each post's metadata separately from its body with Markdown block boundaries" do
    reply = Fabricate(:post, topic: topic, user: user, raw: "Another visible body")

    [
      "/t/#{topic.slug}/#{topic.id}.md",
      "/t/#{topic.slug}/#{topic.id}/#{reply.post_number}.md",
    ].each do |path|
      get path

      posts = path.end_with?("/#{reply.post_number}.md") ? [reply] : [post, reply]
      metadata = response.body.scan(%r{<div class="post-metadata">\n\n(.*?)\n\n</div>}m).flatten
      expect(metadata.size).to eq(posts.size)
      posts
        .zip(metadata)
        .each do |rendered_post, block|
          expect(block).to include("**Author:** ![", "\\\n**Post date:** ")
          rendered_metadata = Nokogiri::HTML5.fragment(PrettyText.cook(block))
          expect(rendered_metadata.css("br").size).to eq(1)
          expect(block).not_to include(rendered_post.raw)
          expect(response.body).to include("</div>\n\n#{rendered_post.raw}")
        end
    end
  end

  it "renders Unicode post authors with percent-encoded avatar URLs" do
    SiteSetting.unicode_usernames = true
    SiteSetting.min_username_length = 2
    SiteSetting.external_system_avatars_url = ""
    user.update!(username: "依云")

    get "/t/#{topic.slug}/#{topic.id}.md"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "**Author:** ![依云](#{Discourse.base_url}/letter_avatar/%E4%BE%9D%E4%BA%91/32/#{LetterAvatar.version}.png) [@依云](#{user.full_url})",
      post.raw,
    )
  end

  it "uses absolute, Markdown-safe URLs for custom post avatars" do
    SiteSetting.default_avatars = "//cdn.example.com/avatar(1).png"

    get "/t/#{topic.slug}/#{topic.id}.md"

    expect(response.body).to include(
      "**Author:** ![#{user.username}](#{Discourse.base_protocol}://cdn.example.com/avatar%281%29.png)",
    )
  end

  it "formats timestamps in the reader's timezone with precise link titles and list reply counts" do
    timestamp = Time.utc(2026, 7, 15, 16, 30, 45)
    post.update_columns(created_at: timestamp)
    topic.update_columns(last_posted_at: timestamp, posts_count: 3)
    user.user_option.update!(timezone: "America/Toronto")
    sign_in(user)

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(
      %(**Post date:** [July 15, 2026, 12:30pm EDT](#{post.full_url} "2026-07-15T12:30:45-04:00")),
    )

    get "/latest.md"
    expect(response.body).to include(
      "**Replies:** 2",
      %(**Last updated:** [July 15, 2026, 12:30pm EDT](#{topic.url} "2026-07-15T12:30:45-04:00")),
    )
  end

  it "uses the application timezone for anonymous timestamps" do
    post.update_columns(created_at: Time.utc(2026, 1, 15, 16, 30, 45))

    Time.use_zone("America/New_York") do
      get "/t/#{topic.slug}/#{topic.id}.md"
      expect(response.body).to include(
        %([January 15, 2026, 11:30am EST](#{post.full_url} "2026-01-15T11:30:45-05:00")),
      )
    end

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(
      %([January 15, 2026, 4:30pm UTC](#{post.full_url} "2026-01-15T16:30:45Z")),
    )

    user.user_option.update!(timezone: nil)
    sign_in(user)
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(
      %([January 15, 2026, 4:30pm UTC](#{post.full_url} "2026-01-15T16:30:45Z")),
    )
  end

  it "preserves topic author filters through discovery and pagination" do
    excluded = Fabricate(:post, topic: topic, raw: "Another author's reply")
    2.times { Fabricate(:post, topic: topic, user: user) }

    [{ username_filters: user.username }, { replies_to_post_number: "1" }].each do |filters|
      get "/t/#{topic.slug}/#{topic.id}", params: filters, headers: { "ACCEPT" => "text/html" }
      alternate = response.headers.fetch("Link")[/<([^>]+)>/, 1]
      expect(Rack::Utils.parse_nested_query(URI(alternate).query)).to eq(filters.stringify_keys)
    end

    stub_const(TopicView, :CHUNK_SIZE, 2) do
      get "/t/#{topic.slug}/#{topic.id}.md", params: { username_filters: user.username }
      next_url = response.body[/\[Next page\]\(([^)]+)\)/, 1]
      expect(Rack::Utils.parse_nested_query(URI(next_url).query)).to eq(
        "page" => "2",
        "username_filters" => user.username,
      )
      get URI(next_url).request_uri
      expect(response.body).not_to include(excluded.raw)
      expect(response.body).to include("username_filters=#{user.username}")
    end
  end

  it "links identical polls to their own posts when caching Markdown bodies" do
    cooked = '<div class="poll"></div>'
    post.update_columns(cooked:)
    reply = Fabricate(:post, topic:, user:, cooked:)

    get "/t/#{topic.slug}/#{topic.id}.md"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "_Poll ([view on site](#{post.full_url}))_",
      "_Poll ([view on site](#{reply.full_url}))_",
    )
  end

  it "invalidates transformed bodies after cooked-only changes in the same second" do
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(post.raw)

    post.update_columns(cooked: "<p>Rebaked body</p>")
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include("Rebaked body")
    expect(response.body).not_to include(post.raw)
  end

  it "renders cooked content with portable links instead of raw authoring syntax" do
    post.update_columns(
      raw: "[details=More]Original source[/details]",
      cooked:
        '<details><summary>More</summary><p>Rendered <strong>content</strong> <a href="/latest">topics</a></p></details>',
    )

    get "/t/#{topic.slug}/#{topic.id}.md"

    expect(response.body).to include(
      "> **More**",
      "Rendered **content**",
      "[topics](#{Discourse.base_url}/latest)",
    )
    expect(response.body).not_to include(post.raw, "<details>")
  end

  it "uses subfolder-safe topic links in lists and discovery" do
    set_subfolder "/forum"

    get "/latest.md"
    expect(response.body).to include("#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}")
    expect(response.body).not_to include("/forum/forum/")

    get "/latest", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to include("#{Discourse.base_url}/latest.md")
    expect(response.headers["Link"]).not_to include("/forum/forum/")
  end

  it "preloads distinct topic authors while rendering lists" do
    3.times do
      author = Fabricate(:user)
      listed_topic = Fabricate(:topic, user: author)
      Fabricate(:post, topic: listed_topic, user: author)
    end

    queries = track_sql_queries { get "/latest.md" }
    individual_author_queries =
      queries.grep(/FROM "users" WHERE "users"\."id" = \d+ (?:ORDER BY .+ )?LIMIT 1/)

    expect(response).to have_http_status(:ok)
    expect(individual_author_queries).to be_empty
  end

  it "preloads and renders localized titles and post bodies" do
    SiteSetting.content_localization_enabled = true
    topic.update!(locale: "ja")
    Fabricate(:topic_localization, topic:, locale: "en", title: "Translated topic title")
    post.update!(locale: "ja")
    Fabricate(:post_localization, post:, locale: "en", cooked: "<p>Translated post 1</p>")
    2.upto(3) do |post_number|
      localized_post =
        Fabricate(:post, topic:, user:, post_number:, locale: "ja", raw: "Original #{post_number}")
      Fabricate(
        :post_localization,
        post: localized_post,
        locale: "en",
        cooked: "<p>Translated post #{post_number}</p>",
      )
    end

    queries = track_sql_queries { get "/t/#{topic.slug}/#{topic.id}.md" }

    expect(response.body).to include("# Translated topic title", "Translated post 3")
    expect(queries.grep(/FROM "post_localizations"/).length).to be <= 2
  end

  it "invalidates transformed bodies when the asset host changes" do
    post.update_columns(cooked: '<p><img src="/uploads/example.png" alt="Example"></p>')

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include("#{Discourse.base_url}/uploads/example.png")

    set_cdn_url "https://cdn.example.test"
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include("https://cdn.example.test/uploads/example.png")
  end

  it "serves the main topic lists by suffix and Accept header" do
    tag = Fabricate(:tag, name: "markdown-tag")
    topic.tags << tag
    subcategory = Fabricate(:category, parent_category: category)
    paths = [
      "/latest",
      "/hot",
      "/top",
      "/c/#{category.slug}/#{category.id}",
      "/c/#{category.slug}/#{subcategory.slug}/#{subcategory.id}",
      "/tag/#{tag.name}",
      "/tag/#{tag.slug_for_url}/#{tag.id}",
    ]

    paths.each do |path|
      ["#{path}.md", path].each do |url|
        get url, headers: { "ACCEPT" => "text/markdown" }
        if response.moved_permanently?
          expect(response.location).to include(".md")
          follow_redirect!
        end
        expect(response).to have_http_status(:ok), "#{url}: #{response.status}"
        expect(response.media_type).to eq("text/markdown"), url
      end
    end
  end

  it "serves personalized new and unread lists with discovery and native filtering" do
    SiteSetting.enable_unified_new = true
    new_topic = Fabricate(:post).topic
    unread_topic = Fabricate(:new_reply_topic, current_user: user)
    read_topic = Fabricate(:read_topic, current_user: user)
    sign_in(user)

    { "/new" => new_topic, "/unread" => unread_topic }.each do |path, expected_topic|
      get "#{path}.json"
      expected_ids =
        response.parsed_body.fetch("topic_list").fetch("topics").map { |entry| entry.fetch("id") }
      expect(expected_ids).to include(expected_topic.id)

      ["#{path}.md", path].each do |url|
        get url, headers: { "ACCEPT" => "text/markdown" }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/markdown")
        ids = response.body.scan(%r{^## \[.*\]\([^\n]*/t/[^\n]+/(\d+)\)$}).flatten.map(&:to_i)
        expect(ids).to match_array(expected_ids)
        expect(response.body).not_to include(read_topic.title)
      end

      get path, headers: { "ACCEPT" => "text/html" }
      expect(response.headers["Link"]).to include(
        "<#{Discourse.base_url}#{path}.md>; rel=\"alternate\"",
      )
      expect(response.body).to include('type="text/markdown"')
    end

    get "/new.md", params: { subset: "replies" }
    expect(response.body).to include(unread_topic.title)
    expect(response.body).not_to include(new_topic.title)
  end

  it "requires authentication for new and unread Markdown lists" do
    %w[/new /unread].each do |path|
      ["#{path}.md", path].each do |url|
        get url, headers: { "ACCEPT" => "text/markdown" }
        expect(response).to have_http_status(:not_found)
        expect(response.media_type).not_to eq("text/markdown")
      end
    end
  end

  it "paginates personalized lists while preserving subset filters" do
    SiteSetting.enable_unified_new = true
    2.times { Fabricate(:new_reply_topic, current_user: user) }
    sign_in(user)

    %w[/new /unread].each do |path|
      get "#{path}.md", params: { per_page: 1, subset: "replies" }
      first_title = response.body[/^## \[(.*?)\]/, 1]
      next_url = response.body[/\[Next page\]\(([^)]+)\)/, 1]
      expect(next_url).to start_with("#{Discourse.base_url}#{path}.md?")
      expect(Rack::Utils.parse_nested_query(URI(next_url).query)).to include(
        "page" => "1",
        "per_page" => "1",
        "subset" => "replies",
      )

      get URI(next_url).request_uri
      expect(response).to have_http_status(:ok)
      expect(response.body[/^## \[(.*?)\]/, 1]).not_to eq(first_title)
      expect(response.body).to include("[Previous page](#{Discourse.base_url}#{path}.md?")
    end
  end

  it "retains native list pagination" do
    TopicQuery::DEFAULT_PER_PAGE_COUNT.times do |index|
      listed_topic = Fabricate(:topic, user: user, title: "Paginated topic #{index}")
      Fabricate(:post, topic: listed_topic, user: user)
    end

    get "/latest.md?page=1"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("**Page:** 2")
    expect(response.body).not_to include("Topics on this page", "[Next page]")
  end

  it "follows Markdown list pagination while retaining filters and subfolder paths" do
    set_subfolder "/forum"
    category.clear_url_cache
    other = Fabricate(:topic, user: user, category: category)
    Fabricate(:post, topic: other, user: user)
    tag = Fabricate(:tag)
    [topic, other].each do |listed_topic|
      listed_topic.tags << tag
      TopicHotScore.create!(topic: listed_topic, score: listed_topic.id)
      TopTopic.create!(topic: listed_topic, yearly_score: listed_topic.id)
    end

    [
      "/latest",
      "/hot",
      "/top",
      "/c/#{category.slug}/#{category.id}",
      "/tag/#{tag.slug_for_url}/#{tag.id}",
    ].each do |path|
      get "#{path}.md", params: { per_page: 1, category: category.id, period: "yearly" }
      expect(response).to have_http_status(:ok), "#{path}: #{response.status} #{response.location}"
      first_title = response.body[/^## \[(.*?)\]/, 1]
      next_url = response.body[/\[Next page\]\(([^)]+)\)/, 1]
      expect(next_url).to start_with("#{Discourse.base_url}#{path}.md?")
      expect(Rack::Utils.parse_nested_query(URI(next_url).query)).to include(
        "page" => "1",
        "per_page" => "1",
      )

      get URI(next_url).request_uri.delete_prefix(Discourse.base_path)
      expect(response).to have_http_status(:ok)
      expect(response.body[/^## \[(.*?)\]/, 1]).not_to eq(first_title)
      previous_url = response.body[/\[Previous page\]\(([^)]+)\)/, 1]
      expect(previous_url).to start_with("#{Discourse.base_url}#{path}.md?")
      get URI(previous_url).request_uri.delete_prefix(Discourse.base_path)
      expect(response.body[/^## \[(.*?)\]/, 1]).to eq(first_title)
    end
  end

  it "preserves topic, category, and tag authorization" do
    private_category = Fabricate(:category, read_restricted: true)
    private_category.set_permissions(staff: :full)
    private_topic =
      Fabricate(:topic, category: private_category, user: user, title: "Restricted private topic")
    private_post = Fabricate(:post, topic: private_topic, user: user, raw: "Private body")

    get "/t/#{private_topic.slug}/#{private_topic.id}.md"
    expect(response).to have_http_status(:not_found)

    get "/latest.md"
    expect(response.body).not_to include(private_topic.title, private_post.raw)

    sign_in(Fabricate(:admin))
    get "/t/#{private_topic.slug}/#{private_topic.id}.md"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(private_post.raw)
  end

  it "preserves personal-message participant checks" do
    recipient = Fabricate(:user)
    private_message = Fabricate(:private_message_topic, user: user, recipient: recipient)
    private_post = Fabricate(:post, topic: private_message, user: user, raw: "Message secret")

    get "/t/#{private_message.slug}/#{private_message.id}.md"
    expect(response).to have_http_status(:not_found)

    sign_in(recipient)
    get "/t/#{private_message.slug}/#{private_message.id}.md"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(private_post.raw)

    SiteSetting.log_personal_messages_views = true
    admin = Fabricate(:admin)
    sign_in(admin)
    get "/t/#{private_message.slug}/#{private_message.id}.md"
    expect(response).to have_http_status(:ok)
    expect(UserHistory.last).to have_attributes(
      acting_user_id: admin.id,
      action: UserHistory.actions[:check_personal_message],
      topic_id: private_message.id,
    )
  end

  it "filters whispers according to the configured groups, including for admins" do
    whisper_group = Fabricate(:group)
    member = Fabricate(:user)
    whisper_group.add(member)
    SiteSetting.whispers_allowed_groups = whisper_group.id.to_s
    whisper =
      Fabricate(
        :post,
        topic: topic,
        user: member,
        post_type: Post.types[:whisper],
        raw: "Group whisper",
      )

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).not_to include(whisper.raw)

    sign_in(Fabricate(:admin))
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).not_to include(whisper.raw)

    sign_in(member)
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(whisper.raw)
  end

  it "uses serialized redaction for hidden posts and does not cache it across readers" do
    post.update!(hidden: true)

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).not_to include(post.raw)
    anonymous_body = response.body

    sign_in(user)
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).not_to include(post.raw)
    expect(response.body).not_to eq(anonymous_body)
  end

  it "uses visible tags and excludes deleted posts from anonymous output" do
    visible_tag = Fabricate(:tag, name: "visible-markdown-tag")
    restricted_tag = Fabricate(:tag, name: "restricted-markdown-tag")
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [restricted_tag.name])
    topic.tags = [visible_tag, restricted_tag]
    deleted_post = Fabricate(:post, topic: topic, user: user, raw: "Deleted body secret")
    deleted_post.trash!

    get "/t/#{topic.slug}/#{topic.id}.md"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(visible_tag.name)
    expect(response.body).not_to include(restricted_tag.name, deleted_post.raw)
  end

  it "advertises only real supported counterparts in headers, HTML, and feeds" do
    tag = Fabricate(:tag, name: "discovery-tag")
    topic.tags << tag

    get "/latest?page=2&unknown=secret", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to include("/latest.md?page=2")
    expect(response.headers["Link"]).not_to include("unknown", "secret")
    expect(response.body).to include('rel="alternate"', 'type="text/markdown"', "/latest.md?page=2")

    [
      "/t/#{topic.slug}/#{topic.id}",
      "/hot",
      "/top",
      "/c/#{category.slug}/#{category.id}",
      "/tag/#{tag.slug_for_url}/#{tag.id}",
    ].each do |path|
      get path, headers: { "ACCEPT" => "text/html" }
      expect(response.headers["Link"]).to include("#{path}.md"), path
      expect(response.body).to include('type="text/markdown"', "#{path}.md"), path
    end

    [
      "/latest.rss?page=2&unknown=secret",
      "/hot.rss",
      "/top.rss?period=yearly",
      "/t/#{topic.slug}/#{topic.id}.rss",
      "/c/#{category.slug}/#{category.id}.rss",
      "/tag/#{tag.slug_for_url}/#{tag.id}.rss",
    ].each do |path|
      get path
      expect(response.body).to include("<atom:link", 'type="text/markdown"'), path
      expect(response.body).not_to include("unknown=secret"), path
    end

    [
      "/about",
      "/topics/created-by/#{user.username}",
      "/u/#{user.username}/activity/topics.rss",
      "/t/#{topic.id}/last",
      "/t/#{topic.id}/summary",
      "/t/#{topic.slug}/#{topic.id}/print",
    ].each do |path|
      get path, headers: { "ACCEPT" => "text/html" }
      expect(response.headers["Link"]).to be_blank, path
      if response.media_type == "text/html"
        expect(response.body).not_to include('type="text/markdown"'), path
      end
    end
  end

  it "preserves safe filters in discovery and Markdown tag redirects" do
    tag = Fabricate(:tag, name: "filtered-markdown-tag")
    topic.tags << tag
    other_topic = Fabricate(:topic, user:, title: "Unfiltered topic")
    Fabricate(:post, topic: other_topic, user:)
    query =
      Rack::Utils.build_nested_query(
        category: category.id,
        tags: [tag.name],
        per_page: 1,
        match_all_tags: true,
        api_key: "api-secret",
        user_api_key: "user-secret",
        api_username: user.username,
        token: "token-secret",
        unknown: "unknown-secret",
      )

    get "/latest?#{query}", headers: { "ACCEPT" => "text/html" }
    alternate_url = response.headers.fetch("Link")[/<([^>]+)>/, 1]
    alternate_query = Rack::Utils.parse_nested_query(URI.parse(alternate_url).query)
    expect(alternate_query).to eq(
      "category" => category.id.to_s,
      "match_all_tags" => "true",
      "per_page" => "1",
      "tags" => [tag.name],
    )

    uri = URI.parse(alternate_url)
    get "#{uri.path}?#{uri.query}"
    expect(response.body).to include(topic.title)
    expect(response.body).not_to include(other_topic.title)

    get "/tag/#{tag.name}.md?#{query}"
    expect(response).to have_http_status(:moved_permanently)
    redirect_query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)
    expect(redirect_query).to eq(alternate_query)
  end

  it "keeps Markdown routes and discovery absent while disabled" do
    SiteSetting.enable_markdown_endpoints = false

    sign_in(user)
    %w[/new /unread].each do |path|
      get "#{path}.md"
      expect(response).to have_http_status(:not_found)

      get path, headers: { "ACCEPT" => "text/markdown" }
      expect(response.media_type).not_to eq("text/markdown")
      expect(response.headers["Link"]).to be_blank
    end

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response).to have_http_status(:not_found)

    get "/t/#{topic.slug}/#{topic.id}", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).not_to eq("text/markdown")

    get "/latest", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to be_blank
    expect(response.body).not_to include('type="text/markdown"')

    get "/", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).not_to eq("text/markdown")

    get "/", headers: { "ACCEPT" => "text/html" }
    expect(response.media_type).to eq("text/html")
    expect(response.headers["Link"]).to be_blank
  end
end

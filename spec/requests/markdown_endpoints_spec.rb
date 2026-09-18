# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Markdown endpoints" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:category)
  fab!(:topic) do
    Fabricate(:topic, user: user, category: category, title: "Markdown endpoint topic")
  end
  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "Visible body") }

  before { SiteSetting.experimental_markdown_endpoints = true }

  def vary_tokens
    response.headers.fetch("Vary", "").split(",").map(&:strip)
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

  it "negotiates category none, top period, and dotted username routes" do
    dotted_user = Fabricate(:user, username: "markdown.user", trust_level: TrustLevel[2])
    dotted_topic = Fabricate(:topic, user: dotted_user)
    Fabricate(:post, topic: dotted_topic, user: dotted_user)

    [
      "/c/#{category.slug}/#{category.id}/none",
      "/top/yearly",
      "/u/#{dotted_user.username}/activity",
    ].each do |path|
      get path, headers: { "ACCEPT" => "text/markdown" }
      expect(response).to have_http_status(:ok), "#{path}: #{response.status}"
      expect(response.media_type).to eq("text/markdown"), path
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

  it "renders one requested post or every visible post without topic pagination" do
    replies =
      2
        .upto(25)
        .map do |post_number|
          Fabricate(
            :post,
            topic: topic,
            user: user,
            post_number: post_number,
            raw: "Reply #{post_number}",
          )
        end

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(post.raw, replies.last.raw, "## Post 25")

    get "/t/#{topic.slug}/#{topic.id}/25.md"
    expect(response.body).to include(
      replies.last.raw,
      "**Showing post:** 25",
      "View the full topic",
    )
    expect(response.body).not_to include(post.raw)
  end

  it "invalidates transformed bodies after cooked-only changes in the same second" do
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include(post.raw)

    post.update_columns(cooked: "<p>Rebaked body</p>")
    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response.body).to include("Rebaked body")
    expect(response.body).not_to include(post.raw)
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

  it "preloads and renders localized titles and all localized post bodies" do
    SiteSetting.content_localization_enabled = true
    topic.update!(locale: "ja")
    Fabricate(:topic_localization, topic:, locale: "en", title: "Translated topic title")
    post.update!(locale: "ja")
    Fabricate(:post_localization, post:, locale: "en", cooked: "<p>Translated post 1</p>")
    2.upto(25) do |post_number|
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

    expect(response.body).to include("# Translated topic title", "Translated post 25")
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

  it "serves root, filter, category, category-without-subcategories, tag, and user lists" do
    tag = Fabricate(:tag, name: "markdown-tag")
    topic.tags << tag
    subcategory = Fabricate(:category, parent_category: category)
    child_topic =
      Fabricate(:topic, category: subcategory, user: user, title: "Child category topic")
    Fabricate(:post, topic: child_topic, user: user)

    [
      "/",
      "/latest.md",
      "/hot.md",
      "/top.md?period=all",
      "/c/#{category.slug}/#{category.id}.md",
      "/tag/#{tag.name}.md",
      "/u/#{user.username}/activity.md",
    ].each do |path|
      get path, headers: ({ "ACCEPT" => "text/markdown" } if path == "/")
      if response.moved_permanently?
        expect(response.location).to include(".md")
        follow_redirect!
      end
      expect(response).to have_http_status(:ok), "#{path}: #{response.status} #{response.body}"
      expect(response.media_type).to eq("text/markdown"), path
    end

    get "/c/#{category.slug}/#{category.id}/l/latest", headers: { "ACCEPT" => "text/markdown" }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")

    get "/tag/#{tag.slug_for_url}/#{tag.id}/l/latest", headers: { "ACCEPT" => "text/markdown" }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")

    get "/c/#{category.slug}/#{category.id}/none.md"
    expect(response.body).to include(topic.title)
    expect(response.body).not_to include(child_topic.title)
  end

  it "retains native list pagination" do
    TopicQuery::DEFAULT_PER_PAGE_COUNT.times do |index|
      listed_topic = Fabricate(:topic, user: user, title: "Paginated topic #{index}")
      Fabricate(:post, topic: listed_topic, user: user)
    end

    get "/latest.md?page=1"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("**Page:** 2", "**Topics on this page:**")
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

  it "enforces profile visibility before querying user activity" do
    profile_user = Fabricate(:user, trust_level: TrustLevel[1])
    profile_topic = Fabricate(:topic, user: profile_user, title: "Hidden profile user topic")
    Fabricate(:post, topic: profile_topic, user: profile_user)
    SiteSetting.allow_users_to_hide_profile = true
    profile_user.user_option.update!(hide_profile: true)

    get "/u/#{profile_user.username}/activity.md"
    expect(response).to have_http_status(:not_found)

    sign_in(profile_user)
    get "/u/#{profile_user.username}/activity.md"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(profile_topic.title)
  end

  it "advertises only real supported counterparts in headers, HTML, and feeds" do
    tag = Fabricate(:tag, name: "discovery-tag")
    topic.tags << tag

    get "/latest?page=2&unknown=secret", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to include("/latest.md?page=2")
    expect(response.headers["Link"]).not_to include("unknown", "secret")
    expect(response.body).to include('rel="alternate"', 'type="text/markdown"', "/latest.md?page=2")

    [
      "/latest.rss?page=2&unknown=secret",
      "/top.rss?period=yearly",
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
    SiteSetting.experimental_markdown_endpoints = false

    get "/t/#{topic.slug}/#{topic.id}.md"
    expect(response).to have_http_status(:not_found)

    get "/t/#{topic.slug}/#{topic.id}", headers: { "ACCEPT" => "text/markdown" }
    expect(response.media_type).not_to eq("text/markdown")

    get "/latest", headers: { "ACCEPT" => "text/html" }
    expect(response.headers["Link"]).to be_blank
    expect(response.body).not_to include('type="text/markdown"')
  end
end

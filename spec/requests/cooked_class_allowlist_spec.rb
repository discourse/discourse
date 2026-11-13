# frozen_string_literal: true

RSpec.describe "cooked class allowlist" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before { sign_in(user) }

  def create_post(raw)
    post "/posts.json", params: { raw: raw, title: "Class allowlist test" }
    expect(response).to have_http_status(:ok)
    Post.find(response.parsed_body["id"])
  end

  def cooked_for(post)
    sign_out
    get "/t/#{post.topic_id}.json"
    expect(response).to have_http_status(:ok)

    posts = response.parsed_body["post_stream"]["posts"]
    posts.find { |cooked_post| cooked_post["id"] == post.id }["cooked"]
  end

  it "does not add classes beyond `quote group-` to a quoted post" do
    post = create_post(<<~RAW.strip)
      <aside class="quote group-team pswp pswp--open">click me</aside>
    RAW

    cooked = cooked_for(post)
    fragment = Nokogiri::HTML5.fragment(cooked)
    aside = fragment.at_css("aside")

    expect(aside["class"].to_s.split).not_to include("pswp", "pswp--open")
    expect(cooked).not_to include("pswp")
  end

  it "does not add classes beyond `lang-` to a code block" do
    post = create_post(<<~RAW.strip)
      <code class="lang-js informations">caption</code>
    RAW

    cooked = cooked_for(post)
    fragment = Nokogiri::HTML5.fragment(cooked)
    code = fragment.at_css("code")

    expect(code["class"].to_s.split).not_to include("informations")
    expect(cooked).not_to include("informations")
  end

  it "does not allow a character reference to smuggle extra quote classes" do
    post = create_post(<<~RAW.strip)
      <aside class="quote group-team&#32;pswp&#32;pswp--open">click me</aside>
      <aside class="quote group-a&#x20;pswp">click me too</aside>
      <aside class="quote group-tab&Tab;pswp">click me as well</aside>
    RAW

    fragment = Nokogiri::HTML5.fragment(cooked_for(post))
    classes = fragment.css("aside").map { |aside| aside["class"].to_s.split }

    expect(classes.flatten).not_to include("pswp", "pswp--open")
    expect(fragment.to_html).not_to include("pswp")
  end

  it "does not allow a character reference to smuggle extra code classes" do
    post = create_post(<<~RAW.strip)
      <code class="lang-js&#32;lazy-video-container">not a video</code>
      <code class="lang-js&#10;lazy-video-container">still not a video</code>
    RAW

    fragment = Nokogiri::HTML5.fragment(cooked_for(post))
    codes = fragment.css("code").map { |code| code["class"].to_s.split }

    expect(codes.flatten).not_to include("lazy-video-container")
    expect(fragment.to_html).not_to include("lazy-video-container")
  end

  it "still allows a single quote and code class token" do
    post = create_post(<<~RAW.strip)
      <aside class="quote no-group">quoted</aside>
      <code class="lang-ruby">puts 1</code>
    RAW

    fragment = Nokogiri::HTML5.fragment(cooked_for(post))

    expect(fragment.at_css("aside")["class"]).to eq("quote no-group")
    expect(fragment.at_css("code")["class"]).to eq("lang-ruby")
  end
end

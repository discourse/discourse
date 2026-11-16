# frozen_string_literal: true

RSpec.describe "HTML requests with API keys" do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }

  def topic_path
    "/t/#{topic.slug}/#{topic.id}"
  end

  def headers_for(api_key, accept: nil)
    headers = { "Api-Key" => api_key.key, "Api-Username" => user.username }
    headers["Accept"] = accept if accept
    headers
  end

  def scoped_api_key
    Fabricate(:api_key, user: user).tap do |api_key|
      ApiKeyScope.create!(api_key_id: api_key.id, resource: "topics", action: "read")
    end
  end

  def read_only_api_key
    Fabricate(:read_only_api_key, user: user)
  end

  def preloaded_json
    element = Nokogiri::HTML5.fragment(response.body).css("script#data-preloaded").first
    element && JSON.parse(element.text)
  end

  def expect_html_rejected
    expect(response.status).to eq(406)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body["errors"]).to contain_exactly(
      I18n.t("scoped_api_key_html_not_allowed"),
    )
    expect(response.body).not_to include("data-preloaded")
    expect(preloaded_json).to be_nil
  end

  def expect_error_page_without_boot_payload(status)
    expect(response.status).to eq(status)
    expect(response.body).not_to include("data-preloaded")
    expect(preloaded_json).to be_nil
  end

  def expect_html_allowed
    expect(response.status).to eq(200)
    expect(JSON.parse(preloaded_json["currentUser"])["id"]).to eq(user.id)
  end

  describe "with an API key that has granular scopes" do
    it "rejects HTML requests that do not state a format" do
      get topic_path, headers: headers_for(scoped_api_key)

      expect_html_rejected
    end

    it "rejects HTML requests that explicitly accept HTML" do
      get topic_path, headers: headers_for(scoped_api_key, accept: "text/html")

      expect_html_rejected
    end

    it "rejects HTML requests from clients that accept any format" do
      get topic_path, headers: headers_for(scoped_api_key, accept: "*/*")

      expect_html_rejected
    end

    it "rejects HTML requests whose Accept header falls back to HTML" do
      [
        "text/plain, text/html",
        "text/css, text/html",
        "image/png, text/html",
        "text/html;q=0.9, text/plain",
        "text/markdown, text/html",
      ].each do |accept|
        get topic_path, headers: headers_for(scoped_api_key, accept:)

        expect_html_rejected
      end
    end

    it "rejects XHR requests that would render the application layout" do
      get topic_path, headers: headers_for(scoped_api_key), xhr: true

      expect_html_rejected
    end

    it "rejects Markdown requests on routes without a Markdown response" do
      get "/about", headers: headers_for(scoped_api_key, accept: "text/markdown")

      expect_html_rejected
    end

    it "serves the non-bootstrapped error page for a missing topic" do
      get "/t/a-missing-topic/99999999", headers: headers_for(scoped_api_key)

      expect_error_page_without_boot_payload(404)
      expect(response.media_type).to eq("text/html")
    end

    it "serves the non-bootstrapped error page to clients that accept any format" do
      get "/t/a-missing-topic/99999999", headers: headers_for(scoped_api_key, accept: "*/*")

      expect_error_page_without_boot_payload(404)
    end

    it "refuses to bootstrap the application layout on error pages" do
      SiteSetting.bootstrap_error_pages = true

      get "/t/a-missing-topic/99999999", headers: headers_for(scoped_api_key)

      expect_html_rejected
    end

    it "refuses bootstrapped error pages even for non-HTML requested formats" do
      SiteSetting.bootstrap_error_pages = true

      get "/t/a-missing-topic/99999999.rss", headers: headers_for(scoped_api_key)

      expect_html_rejected
    end

    it "serves the error page for a topic the credential cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)

      get "/t/#{private_topic.slug}/#{private_topic.id}", headers: headers_for(scoped_api_key)

      expect_error_page_without_boot_payload(404)
    end

    it "still serves the JSON representation" do
      get "#{topic_path}.json", headers: headers_for(scoped_api_key)

      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq(topic.id)
    end

    it "still serves JSON to clients that explicitly accept JSON" do
      get topic_path, headers: headers_for(scoped_api_key, accept: "application/json")

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body["id"]).to eq(topic.id)
    end

    it "still serves RSS feeds" do
      get "#{topic_path}.rss", headers: headers_for(scoped_api_key)

      expect(response.status).to eq(200)
    end

    it "still serves JSON errors" do
      get "/t/a-missing-topic/99999999.json", headers: headers_for(scoped_api_key)

      expect(response.status).to eq(404)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "still redirects to canonical URLs" do
      get "/t/#{topic.id}", headers: headers_for(scoped_api_key)

      expect(response.status).to eq(301)
      expect(response.location).to end_with(topic_path)
    end

    it "still serves HEAD requests" do
      head topic_path, headers: headers_for(scoped_api_key)

      expect(response.status).to eq(200)
    end

    it "still serves non-GET actions" do
      member = Fabricate(:user, trust_level: TrustLevel[2])
      member_topic = Fabricate(:topic, user: member)
      Fabricate(:post, topic: member_topic, user: member)
      api_key =
        Fabricate(:api_key, user: member).tap do |key|
          ApiKeyScope.create!(api_key_id: key.id, resource: "topics", action: "write")
        end

      post "/posts",
           headers: {
             "Api-Key" => api_key.key,
             "Api-Username" => member.username,
             "Accept" => "text/html",
           },
           params: {
             topic_id: member_topic.id,
             raw: "A post created through a scoped API key",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to be_present
    end

    it "keeps non-GET error responses unchanged" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      private_post = Fabricate(:post, topic: private_topic)
      api_key =
        Fabricate(:api_key, user: user).tap do |key|
          ApiKeyScope.create!(api_key_id: key.id, resource: "topics", action: "change_owner")
        end

      post "/t/#{private_topic.id}/change-owner",
           headers: headers_for(api_key, accept: "text/html"),
           params: {
             username: user.username,
             post_ids: [private_post.id],
           }

      expect(response.status).to eq(403)
      expect(response.body).not_to include("data-preloaded")
    end
  end

  describe "with an API key without scopes" do
    it "serves the HTML application with the authenticated boot payload" do
      get topic_path, headers: headers_for(Fabricate(:api_key, user: user))

      expect_html_allowed
    end
  end

  describe "with a read-only API key" do
    it "serves the HTML application with the authenticated boot payload" do
      get topic_path, headers: headers_for(read_only_api_key)

      expect_html_allowed
    end
  end

  describe "with a user API key" do
    def headers_for_user_api_key(*scope_names)
      api_key =
        Fabricate(
          :user_api_key,
          user: user,
          scopes: scope_names.map { |name| UserApiKeyScope.new(name:) },
        )
      { "User-Api-Key" => api_key.key }
    end

    it "serves HTML requests with the read scope" do
      get "/latest", headers: headers_for_user_api_key("read")

      expect_html_allowed
    end

    it "serves HTML requests with the write scope" do
      get "/latest", headers: headers_for_user_api_key("write")

      expect_html_allowed
    end

    it "rejects HTML requests with any other scope" do
      get "/notifications", headers: headers_for_user_api_key("notifications")

      expect_html_rejected
    end

    it "rejects Markdown requests that fall back to the application layout" do
      get "/notifications",
          headers: headers_for_user_api_key("notifications").merge("Accept" => "text/markdown")

      expect_html_rejected
    end

    it "still serves the JSON representation with any other scope" do
      get "/notifications.json", headers: headers_for_user_api_key("notifications")

      expect(response.status).to eq(200)
    end

    it "keeps the forbidden status when a feed key requests another user's feed" do
      other_user = Fabricate(:user)
      api_key = Fabricate(:bookmarks_calendar_user_api_key, user: user)

      get "/u/#{other_user.username}/bookmarks.ics", params: { user_api_key: api_key.key }

      expect_error_page_without_boot_payload(403)
    end
  end
end

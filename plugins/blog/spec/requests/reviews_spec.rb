# frozen_string_literal: true

RSpec.describe "External draft review", type: :request do
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
      raw: "A private article for external editorial review.",
    )
  end

  before { enable_blog!(category: category, drafts: drafts) }

  def issue_review
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    post "https://test.localhost/blog-editor/publications/#{topic.id}/reviews.json",
         params: {
           label: "Editorial round",
         }
    expect(response.status).to eq(201)
    review = response.parsed_body["review"]
    [review, Rack::Utils.parse_query(URI(review["url"]).query)["review_token"]]
  end

  it "rejects account-free reviews when anonymous upload downloads are disabled" do
    review, token = issue_review
    SiteSetting.prevent_anons_from_downloading_files = true

    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)

    post "https://test.localhost/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.status).to eq(400)
    expect(Blog::Review.where(topic: topic).pluck(:id)).to eq([review["id"]])
  end

  it "requires an authorized editor and keeps issued links readable by editors" do
    post "/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.status).to eq(403)
    sign_in(user)
    post "/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.status).to eq(403)
    review, token = issue_review
    stored = Blog::Review.find(review["id"])
    expect(stored.token).to eq(token)
    expect(stored.expires_at).to be_within(2.seconds).of(7.days.from_now)

    # The link stays retrievable, so a lost link does not force a new one.
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.parsed_body["reviews"].first["url"]).to eq(review["url"])
    sign_in(user)
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.status).to eq(403)
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    expect(topic.reload.category_id).to eq(drafts.id)
    expect(Blog::Publication.where(topic: topic, published: true)).not_to exist
    expect(UserHistory.where(custom_type: "blog_review_create", acting_user_id: admin.id)).to exist
  end

  it "shares a sanitized frozen revision without staff replies or custom code" do
    private_reply =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        raw: "This internal editorial conversation must not be shared.",
      )
    review, token = issue_review
    snapshot = Blog::Review.find(review["id"]).cooked
    first_post.revise(
      admin,
      raw: "New unpublished changes should not reach the reviewer automatically.",
    )
    theme =
      Blog::BlogTheme.save(
        {
          "name" => "Spec design",
          "accent_color" => "d64b2a",
          "paper_color" => "f5f0e6",
          "ink_color" => "19382d",
          "css" => "",
          "javascript" => "window.privateBlogScript = true;",
        },
        user: admin,
      )
    Blog::BlogTheme.activate(theme["id"], revision: 1, user: admin)

    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(200)
    expect(response.parsed_body["cooked"]).to eq(snapshot)
    expect(response.body).not_to include(private_reply.raw, first_post.reload.raw)
    expect(response.parsed_body.keys).to contain_exactly(
      "title",
      "cooked",
      "post_version",
      "created_at",
      "expires_at",
    )
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.headers["X-Robots-Tag"]).to include("noindex")
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    get "https://blog.example.com/blog/review", params: { review_token: token }
    expect(response.status).to eq(200)
    expect(response.body).not_to include("blog-custom.js", "data-theme-id=", private_reply.raw)
    expect(response.body).to include("no_themes")
    # Review links are blog-origin capabilities; the discussion host keeps core's own /review route.
    get "https://test.localhost/review", params: { review_token: token }
    expect(response.body).not_to include(snapshot)
    expect(Rails.application.routes.recognize_path("/review", method: :get)).to eq(
      controller: "reviewables",
      action: "index",
    )
  end

  it "keeps anonymous feedback private even after publication" do
    review, token = issue_review
    message = "Please reconsider the conclusion before publication."
    post "https://blog.example.com/blog/review/feedback.json",
         params: {
           review_token: token,
           feedback: {
             name: "Reviewer",
             email: "reviewer@example.com",
             message: message,
           },
         },
         headers: {
           "Origin" => "https://blog.example.com",
         }
    expect(response.status).to eq(204)
    expect(topic.posts.count).to eq(1)
    expect(Blog::ReviewFeedback.find_by!(review_id: review["id"]).message).to eq(message)

    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews/#{review["id"]}/feedback.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["feedback"].first["message"]).to eq(message)
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.parsed_body["reviews"].first["feedback_count"]).to eq(1)
    Blog::Publication.for_topic(topic).publish!(admin)
    expect(Blog::Review.find(review["id"]).revoked_at).to be_present
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews/#{review["id"]}/feedback.json"
    expect(response.parsed_body["feedback"].first["message"]).to eq(message)
    expect(topic.posts.pluck(:raw)).not_to include(message)
  end

  it "revokes links and rejects forged tokens and cross-origin feedback" do
    review, token = issue_review
    post "https://blog.example.com/blog/review/feedback.json",
         params: {
           review_token: token,
           feedback: {
             message: "Unexpected feedback",
           },
         },
         headers: {
           "Origin" => "https://elsewhere.example",
         }
    expect(response.status).to eq(403)
    get "https://blog.example.com/blog/review.json", params: { review_token: "x" * 43 }
    expect(response.status).to eq(404)
    delete "https://test.localhost/blog-editor/publications/#{topic.id}/reviews/#{review["id"]}.json"
    expect(response.status).to eq(204)
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
    post "https://blog.example.com/blog/review/feedback.json",
         params: {
           review_token: token,
           feedback: {
             message: "Late feedback",
           },
         },
         headers: {
           "Origin" => "https://blog.example.com",
         }
    expect(response.status).to eq(404)
    expect(Blog::ReviewFeedback.count).to eq(0)
  end

  it "rejects expired links, inaccessible articles, and revoked creator access" do
    review, token = issue_review
    Blog::Review.find(review["id"]).update!(expires_at: 1.minute.ago)
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
    _, token = issue_review
    first_post.update!(hidden: true)
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
    first_post.update!(hidden: false)
    _, token = issue_review
    admin.update!(admin: false)
    admin.reload.update!(moderator: false)
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
  end

  it "validates feedback and scopes management endpoints to their topic" do
    review, token = issue_review
    ["", "x" * 10_001].each do |message|
      post "https://blog.example.com/blog/review/feedback.json",
           params: {
             review_token: token,
             feedback: {
               message: message,
             },
           },
           headers: {
             "Origin" => "https://blog.example.com",
           }
      expect(response.status).to eq(422)
    end
    other = Fabricate(:topic, category: drafts, user: admin)
    Fabricate(:post, topic: other, user: admin)
    delete "https://test.localhost/blog-editor/publications/#{other.id}/reviews/#{review["id"]}.json"
    expect(response.status).to eq(404)
    get "https://test.localhost/session/#{user.encoded_username}/become"
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews/#{review["id"]}/feedback.json"
    expect(response.status).to eq(403)
    expect(Blog::ReviewFeedback.count).to eq(0)
  end

  it "requires a real CSRF token for anonymous feedback" do
    _, token = issue_review
    previous = Blog::ReviewReaderController.allow_forgery_protection
    Blog::ReviewReaderController.allow_forgery_protection = true
    begin
      post "https://blog.example.com/blog/review/feedback.json",
           params: {
             review_token: token,
             feedback: {
               message: "Missing CSRF",
             },
           },
           headers: {
             "Origin" => "https://blog.example.com",
           }
      expect(response.status).to eq(403)
      get "https://blog.example.com/session/csrf.json"
      expect(response.status).to eq(200)
      csrf = response.parsed_body["csrf"]
      post "https://blog.example.com/blog/review/feedback.json",
           params: {
             review_token: token,
             feedback: {
               message: "Legitimate anonymous feedback",
             },
           },
           headers: {
             "Origin" => "https://blog.example.com",
             "X-CSRF-Token" => csrf,
           }
      expect(response.status).to eq(204)
      expect(Blog::ReviewFeedback.count).to eq(1)
    ensure
      Blog::ReviewReaderController.allow_forgery_protection = previous
    end
  end

  it "excludes unrelated plugins, themes, and analytics from the review boot" do
    # Backend CI doesn't build plugin JS, so give every plugin a bundle to filter.
    allow(Plugin::JsManager).to receive(:read_manifest) do |name|
      { "main" => { "fileName" => "#{name}.js", "imports" => [], "externalPluginImports" => [] } }
    end
    _, token = issue_review
    get "https://blog.example.com/blog/review", params: { review_token: token }
    expect(response.status).to eq(200)
    document = Nokogiri.HTML5(response.body)
    plugin_names =
      document.css("[data-plugin-name]").map { |element| element["data-plugin-name"] }.uniq
    expect(plugin_names).to eq(["blog"])
    expect(document.css("[data-theme-id], iframe, script[data-blog-custom-script]")).to be_empty
    expect(document.at_css("#data-discourse-setup")["data-service-worker-url"]).to be_nil
    expect(response.body).not_to include("googletagmanager.com", "google-analytics.com")
  end

  it "revokes grants when a privileged operation moves a topic out of drafts" do
    review, token = issue_review
    topic.category_id = category.id
    topic.save!(validate: false)
    expect(Blog::Review.find(review["id"]).revoked_at).to be_present
    topic.update!(category_id: drafts.id)
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
  end

  it "rate-limits anonymous feedback without creating extra entries" do
    _, token = issue_review
    RateLimiter.enable
    30.times do
      post "https://blog.example.com/blog/review/feedback.json",
           params: {
             review_token: token,
             feedback: {
               message: "Feedback",
             },
           },
           headers: {
             "Origin" => "https://blog.example.com",
           }
      expect(response.status).to eq(204)
    end
    post "https://blog.example.com/blog/review/feedback.json",
         params: {
           review_token: token,
           feedback: {
             message: "Over the limit",
           },
         },
         headers: {
           "Origin" => "https://blog.example.com",
         }
    expect(response.status).to eq(429)
    expect(Blog::ReviewFeedback.count).to eq(30)
  ensure
    RateLimiter.disable
  end

  it "bounds stored feedback and paginates the private editor view" do
    review, token = issue_review
    now = Time.current
    Blog::ReviewFeedback.insert_all!(
      200.times.map do |index|
        {
          review_id: review["id"],
          name: "",
          email: "",
          message: "Response #{index}",
          created_at: now,
          updated_at: now,
        }
      end,
    )
    post "https://blog.example.com/blog/review/feedback.json",
         params: {
           review_token: token,
           feedback: {
             message: "Too many responses",
           },
         },
         headers: {
           "Origin" => "https://blog.example.com",
         }
    expect(response.status).to eq(400)
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews/#{review["id"]}/feedback.json"
    expect(response.parsed_body["feedback"].length).to eq(30)
    expect(response.parsed_body["more"]).to eq(true)
    first_ids = response.parsed_body["feedback"].map { |entry| entry["id"] }
    get "https://test.localhost/blog-editor/publications/#{topic.id}/reviews/#{review["id"]}/feedback.json",
        params: {
          page: 1,
        }
    expect(response.parsed_body["feedback"].map { |entry| entry["id"] } & first_ids).to be_empty
  end

  it "sanitizes stored markup and deletes snapshots and feedback with a hard-deleted topic" do
    first_post.update_columns(
      cooked:
        '<p>Review text</p><script>alert(1)</script><iframe src="https://example.com"></iframe>',
    )
    review, token = issue_review
    stored = Blog::Review.find(review["id"])
    expect(Nokogiri::HTML5.fragment(stored.cooked).css("script, iframe")).to be_empty
    stored.feedback.create!(message: "A private response", name: nil, email: nil)
    topic.destroy!
    expect(Blog::Review.where(id: review["id"])).not_to exist
    expect(Blog::ReviewFeedback.where(review_id: review["id"])).not_to exist
    get "https://blog.example.com/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(404)
  end
end

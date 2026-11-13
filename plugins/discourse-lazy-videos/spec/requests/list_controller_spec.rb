# frozen_string_literal: true

RSpec.describe ListController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  it "does not break the latest feed when a post forges a lazy video container" do
    sign_in(user)
    post "/posts.json",
         params: {
           raw: '<code class="lang-js lazy-video-container">not a video</code>',
           title: "Forged lazy video container",
         }
    expect(response).to have_http_status(:ok)

    sign_out
    get "/latest.rss"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
  end

  it "does not break the latest feed for a link-less container in stored cooked HTML" do
    post = Fabricate(:post)
    post.update_column(:cooked, <<~HTML)
      <div class="youtube-onebox lazy-video-container" data-video-title="No link here">not a video</div>
    HTML

    get "/latest.rss"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
  end
end

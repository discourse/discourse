# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:poster, :trust_level_1)
  fab!(:topic)

  it "does not include executable markup from a provider video title in email output" do
    video_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    video_title = 'Video "><img src=x onerror="alert(1)">'
    thumbnail_url = "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"

    SiteSetting.lazy_videos_enabled = true
    SiteSetting.lazy_youtube_enabled = true
    Oneboxer.invalidate(video_url)
    stub_request(:get, video_url).to_return(status: 200, body: "<html></html>")
    stub_request(:head, video_url).to_return(status: 200)
    stub_request(:get, thumbnail_url).to_return(status: 200, body: "")
    stub_request(:head, thumbnail_url).to_return(status: 200)
    stub_request(:get, "https://www.youtube.com/oembed?url=#{video_url}").to_return(
      status: 200,
      body: JSON.dump(title: video_title, thumbnail_url: thumbnail_url),
    )

    sign_in(poster)
    get "/onebox.json", params: { url: video_url, refresh: "true" }

    expect(response).to have_http_status(:ok)

    post "/posts.json", params: { raw: video_url, topic_id: topic.id }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("id" => be_present)

    created_post = Post.find(response.parsed_body["id"])
    fragment =
      Nokogiri::HTML5.fragment(PrettyText.format_for_email(created_post.cooked, created_post))
    expect(fragment.css("img[onerror]")).to be_empty
    expect(fragment.at_css("a").text).to eq(video_title)
  end
end

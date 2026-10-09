# frozen_string_literal: true

RSpec.describe Onebox::Engine::YoutubeOnebox do
  let(:video_id) { "IYH7_GzP4Tg" }
  let(:list_id) { "RDIYH7_GzP4Tg" }
  let(:video_url) { "https://www.youtube.com/watch?v=#{video_id}&list=#{list_id}&start_radio=1" }

  before do
    SiteSetting.lazy_videos_enabled = true
    SiteSetting.lazy_youtube_enabled = true

    stub_request(:get, video_url).to_return(status: 200, body: onebox_response("youtube"))
    stub_request(:get, %r{https://www\.youtube\.com/oembed\?}).to_return(
      status: 200,
      body: {
        title: "Lil Jon & The East Side Boyz - Get Low",
        thumbnail_url: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg",
      }.to_json,
    )
    stub_request(:get, "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg").to_return(
      status: 200,
    )
  end

  it "creates a lazy video that preserves its playlist" do
    html = Onebox.preview(video_url).to_s

    expect(html).to include(
      "lazy-video-container",
      %(data-video-list-id="#{list_id}"),
      "https://www.youtube.com/watch?v=#{video_id}&amp;list=#{list_id}",
    )
  end
end

# frozen_string_literal: true

RSpec.describe "Chat lazy YouTube videos" do
  fab!(:current_user, :user)
  fab!(:channel, :category_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  let(:video_id) { "dQw4w9WgXcQ" }
  let(:video_title) { "Rick Astley - Never Gonna Give You Up" }
  let(:thumbnail_url) { "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg" }

  let(:oembed_response) do
    {
      title: video_title,
      author_name: "RickAstleyVEVO",
      type: "video",
      thumbnail_url: thumbnail_url,
    }.to_json
  end

  let(:youtube_html) { <<~HTML }
      <html>
      <head>
        <meta property="og:title" content="#{video_title}">
        <meta property="og:image" content="#{thumbnail_url}">
      </head>
      <body></body>
      </html>
    HTML

  before do
    chat_system_bootstrap
    channel.add(current_user)
    sign_in(current_user)

    # NOTE: This spec is testing integration with the core discourse-lazy-videos plugin.
    SiteSetting.lazy_videos_enabled = true
    SiteSetting.lazy_youtube_enabled = true

    stub_request(:get, "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg").to_return(
      status: 200,
      body: "",
    )
    stub_request(:head, "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg").to_return(
      status: 200,
      body: "",
    )
  end

  def stub_youtube_requests(url)
    stub_request(:get, url).to_return(status: 200, body: youtube_html)
    stub_request(:head, url).to_return(status: 200, body: "")
  end

  def stub_oembed_request(url)
    stub_request(:get, "https://www.youtube.com/oembed?url=#{url}").to_return(
      status: 200,
      body: oembed_response,
    )
  end

  context "with youtube.com URLs" do
    let(:youtube_url) { "https://www.youtube.com/watch?v=#{video_id}" }

    before do
      stub_youtube_requests(youtube_url)
      stub_oembed_request(youtube_url)
    end

    it "shows a lazy video with and without a timestamp in youtube.com links" do
      url_with_time = "#{youtube_url}&t=42"
      stub_youtube_requests(url_with_time)
      stub_oembed_request(url_with_time)

      chat_page.visit_channel(channel)

      channel_page.send_message(youtube_url)
      expect(page).to have_css(".lazy-video-container[data-video-id='#{video_id}']", count: 1)

      channel_page.send_message(url_with_time)
      expect(page).to have_css(".lazy-video-container[data-video-id='#{video_id}']", count: 2)
      expect(page).to have_css(
        ".lazy-video-container[data-video-id='#{video_id}'][data-video-start-time='42']",
        count: 1,
      )
    end
  end

  context "with a provider title containing markup" do
    let(:video_title) do
      'Video</a><a class="provider-title-injection" href="https://attacker.example">Open account settings</a>'
    end

    let(:youtube_url) { "https://www.youtube.com/watch?v=#{video_id}" }

    before do
      stub_youtube_requests(youtube_url)
      stub_oembed_request(youtube_url)
      Oneboxer.invalidate(youtube_url)
    end

    it "renders the provider title as text rather than a link" do
      chat_page.visit_channel(channel)
      channel_page.send_message(youtube_url)

      expect(page).to have_no_css(".provider-title-injection")
      expect(page).to have_css(".chat-message-collapser-link", text: video_title)
    end
  end

  context "with youtu.be URLs" do
    let(:youtu_be_url) { "https://youtu.be/#{video_id}" }

    before do
      stub_youtube_requests(youtu_be_url)
      stub_oembed_request(youtu_be_url)
    end

    it "shows lazy videos for short links and keeps timestamps with or without a share parameter" do
      timed_url = "#{youtu_be_url}?t=42"
      shared_url = "#{youtu_be_url}?si=abc123&t=42"
      stub_youtube_requests(timed_url)
      stub_oembed_request(timed_url)
      stub_youtube_requests(shared_url)
      stub_oembed_request(shared_url)

      chat_page.visit_channel(channel)

      video = ".lazy-video-container[data-video-id='#{video_id}']"
      timed_video = "#{video}[data-video-start-time='42']"

      channel_page.send_message(youtu_be_url)
      expect(page).to have_css(video, count: 1)

      channel_page.send_message(timed_url)
      expect(page).to have_css(timed_video, count: 1)

      channel_page.send_message(shared_url)
      expect(page).to have_css(timed_video, count: 2)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Onebox::Engine::YoutubeOnebox do
  let(:oembed_standard_response) do
    {
      title: "96neko - orange",
      author_name: "96neko",
      type: "video",
      thumbnail_url: "https://i.ytimg.com/vi/21Lk4YiASMo/hqdefault.jpg",
    }.to_json
  end

  before do
    stub_request(
      :get,
      "https://www.youtube.com/watch?feature=player_embedded&v=21Lk4YiASMo",
    ).to_return(status: 200, body: onebox_response("youtube"))
    stub_request(:get, "https://youtu.be/21Lk4YiASMo").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )
    stub_request(:get, "https://www.youtube.com/embed/21Lk4YiASMo").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )
    stub_request(:get, "http://www.youtube.com/watch?v=21Lk4YiASMo").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )
    stub_request(:get, "https://www.youtube.com/watch?v=21Lk4YiASMo").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )
    stub_request(:get, "https://www.youtube.com/live/eJemwqO0SDw").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )
    stub_request(:get, "https://www.youtube.com/embed/eJemwqO0SDw").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )

    stub_request(:get, "https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ").to_return(
      status: 200,
      body: onebox_response("youtube-channel"),
    )
    stub_request(:get, "http://www.youtube.com/user/googlechrome").to_return(
      status: 200,
      body: onebox_response("youtube-channel"),
    )

    stub_request(:get, "https://www.youtube.com/playlist?list=PL5308B2E5749D1696").to_return(
      status: 200,
      body: onebox_response("youtube-playlist"),
    )

    stub_request(:get, "https://www.youtube.com/embed/KCyIfcevExE").to_return(
      status: 200,
      body: onebox_response("youtube-embed"),
    )

    stub_request(:get, "https://www.youtube.com/embed/VvoFuaLAslw").to_return(
      status: 200,
      body: onebox_response("youtube-shorts"),
    )

    stub_request(:get, "https://www.youtube.com/watch?v=KCyIfcevExE").to_return(
      status: 200,
      body: onebox_response("youtube"),
    )

    stub_request(:get, "https://youtube.com/shorts/VvoFuaLAslw").to_return(
      status: 200,
      body: onebox_response("youtube-shorts"),
    )

    # Stub oEmbed API calls for video URLs
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=https://www\.youtube\.com/watch},
    ).to_return(status: 200, body: oembed_standard_response)
    # Make oEmbed fail for KCyIfcevExE to test fallback to embed page parsing
    # Must come after the general stub to override it
    stub_request(
      :get,
      "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=KCyIfcevExE",
    ).to_return(status: 404)
    stub_request(:get, %r{https://www\.youtube\.com/oembed\?url=https://youtu\.be}).to_return(
      status: 200,
      body: oembed_standard_response,
    )
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=http://www\.youtube\.com/watch},
    ).to_return(status: 200, body: oembed_standard_response)
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=https://www\.youtube\.com/live},
    ).to_return(status: 200, body: oembed_standard_response)
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=https://youtube\.com/shorts},
    ).to_return(
      status: 200,
      body: {
        title: "POMBO",
        thumbnail_url: "https://i.ytimg.com/vi/VvoFuaLAslw/hqdefault.jpg",
      }.to_json,
    )

    # Channels, playlists, etc. don't support oEmbed - return 404
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=https://www\.youtube\.com/channel},
    ).to_return(status: 404)
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=http://www\.youtube\.com/user},
    ).to_return(status: 404)
    stub_request(
      :get,
      %r{https://www\.youtube\.com/oembed\?url=https://www\.youtube\.com/playlist},
    ).to_return(status: 404)
  end

  it "adds wmode=opaque" do
    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo").to_s).to match(
      /wmode=opaque/,
    )
  end

  it "rewrites URLs for videos to be HTTPS" do
    # match: plain HTTP and protocol agnostic
    regex = %r{(http:|["']//)}

    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo").to_s).not_to match(regex)
    expect(
      Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo").placeholder_html,
    ).not_to match(regex)
    expect(
      Onebox.preview("https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ").to_s,
    ).not_to match(regex)
  end

  it "can onebox a channel page" do
    expect(
      Onebox.preview("https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ").to_s,
    ).to match(/Google Chrome/)
  end

  it "can onebox a playlist" do
    expect(
      Onebox.preview("https://www.youtube.com/playlist?list=PL5308B2E5749D1696").to_s,
    ).to match(/iframe/)
    placeholder_html =
      Onebox.preview("https://www.youtube.com/playlist?list=PL5308B2E5749D1696").placeholder_html
    expect(placeholder_html).to match(/<img/)
    expect(placeholder_html).to include("The web is what you make of it")
  end

  it "does not make HTTP requests unless necessary" do
    # We haven't defined any fixture for requests associated with this ID, so if
    # any HTTP requests are made webmock will complain and the test will fail.
    Onebox.preview("http://www.youtube.com/watch?v=q39Ce3zDScI").to_s
  end

  it "does not fail if we cannot get the video ID from the URL" do
    expect(
      Onebox.preview("http://www.youtube.com/watch?feature=player_embedded&v=21Lk4YiASMo").to_s,
    ).to match(/embed/)
  end

  it "returns an image as the placeholder" do
    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo").placeholder_html).to match(
      /<img/,
    )
    expect(Onebox.preview("https://www.youtube.com/live/eJemwqO0SDw").placeholder_html).to match(
      /<img/,
    )
    expect(Onebox.preview("https://youtu.be/21Lk4YiASMo").placeholder_html).to match(/<img/)
  end

  it "passes the playlist ID through" do
    expect(
      Onebox.preview(
        "https://www.youtube.com/watch?v=21Lk4YiASMo&list=UUQau-O2C0kGJpR3_CHBTGbw&index=1",
      ).to_s,
    ).to match(/UUQau-O2C0kGJpR3_CHBTGbw/)
  end

  it "filters out nonsense parameters" do
    expect(
      Onebox.preview(
        "https://www.youtube.com/watch?v=21Lk4YiASMo&potential[]=exploit&potential[]=fun",
      ).to_s,
    ).not_to match(/potential|exploit|fun/)
  end

  it "ignores video_id with unacceptable characters" do
    # (falls back to generic onebox)
    Onebox::Engine::AllowlistedGenericOnebox
      .any_instance
      .stubs(:to_html)
      .returns(+"allowlisted_html")
    expect(Onebox.preview("https://www.youtube.com/watch?v=%3C%3E21Lk4YiASMo").to_s).to eq(
      "allowlisted_html",
    )
  end

  it "ignores list_id with unacceptable characters" do
    # (falls back to video-only onebox)
    expect(
      Onebox.preview(
        "https://www.youtube.com/watch?v=21Lk4YiASMo&list=%3C%3EUUQau-O2C0kGJpR3_CHBTGbw",
      ).to_s,
    ).not_to include("UUQau-O2C0kGJpR3_CHBTGbw")
  end

  it "converts time strings into a &start= parameter" do
    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo&start=3782").to_s).to match(
      /start=3782/,
    )
    expect(
      Onebox.preview("https://www.youtube.com/watch?start=1h3m2s&v=21Lk4YiASMo").to_s,
    ).to match(/start=3782/)
    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo&t=1h3m2s").to_s).to match(
      /start=3782/,
    )
    expect(
      Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo&start=1h3m2s").to_s,
    ).to match(/start=3782/)
    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo#t=1h3m2s").to_s).to match(
      /start=3782/,
    )
  end

  it "allows both start and end" do
    preview =
      expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo&start=2m&end=3m").to_s)
    preview.to match(/start=120/)
    preview.to match(/end=180/)
  end

  it "permits looping videos" do
    preview = expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo&loop").to_s)
    preview.to match(/loop=1/)
    preview.to match(/playlist=21Lk4YiASMo/)
  end

  it "includes title in preview" do
    expect(Onebox.preview("https://youtu.be/21Lk4YiASMo").placeholder_html).to include(
      "96neko - orange",
    )
  end

  it "can parse youtube embed results" do
    preview = expect(Onebox.preview("https://www.youtube.com/watch?v=KCyIfcevExE").placeholder_html)
    preview.to match(/Delvon/)
    preview.to match(/hqdefault/)
  end

  it "can parse youtube shorts results" do
    preview = expect(Onebox.preview("https://youtube.com/shorts/VvoFuaLAslw").placeholder_html)
    preview.to match(/POMBO/)
    preview.to match(/hqdefault/)
  end

  it "can parse youtube live URLs" do
    preview = expect(Onebox.preview("https://www.youtube.com/live/eJemwqO0SDw").to_s)
    preview.to match(/iframe/)
    preview.to include("embed/eJemwqO0SDw")
  end

  it "generates a thumbnail for videos" do
    expect(Onebox.preview("https://www.youtube.com/watch?v=21Lk4YiASMo").to_s).to match("<img")
  end

  describe "oEmbed support" do
    let(:video_url) { "https://www.youtube.com/watch?v=wC10VWDTzmU" }
    let(:oembed_url) { "https://www.youtube.com/oembed?url=#{video_url}" }
    let(:oembed_response) do
      {
        title: "Bob Dylan - Gotta Serve Somebody (Official Audio)",
        author_name: "BobDylanVEVO",
        author_url: "https://www.youtube.com/@BobDylanVEVO",
        type: "video",
        height: 113,
        width: 200,
        version: "1.0",
        provider_name: "YouTube",
        provider_url: "https://www.youtube.com/",
        thumbnail_height: 360,
        thumbnail_width: 480,
        thumbnail_url: "https://i.ytimg.com/vi/wC10VWDTzmU/hqdefault.jpg",
        html:
          '<iframe width="200" height="113" src="https://www.youtube.com/embed/wC10VWDTzmU?feature=oembed"></iframe>',
      }.to_json
    end

    before do
      stub_request(:get, oembed_url).to_return(status: 200, body: oembed_response)
      stub_request(:get, video_url).to_return(status: 200, body: onebox_response("youtube"))
    end

    it "uses oEmbed API for metadata" do
      onebox = Onebox::Engine::YoutubeOnebox.new(video_url)
      result = onebox.send(:parse_embed_response)

      expect(result).to be_present
      expect(result[:title]).to eq("Bob Dylan - Gotta Serve Somebody (Official Audio)")
      expect(result[:image]).to eq("https://i.ytimg.com/vi/wC10VWDTzmU/hqdefault.jpg")
    end

    it "includes oEmbed data in placeholder_html" do
      placeholder = Onebox.preview(video_url).placeholder_html

      expect(placeholder).to include("Bob Dylan - Gotta Serve Somebody (Official Audio)")
      expect(placeholder).to include("https://i.ytimg.com/vi/wC10VWDTzmU/hqdefault.jpg")
      expect(placeholder).to match(/<img/)
    end

    it "falls back to OpenGraph when oEmbed fails" do
      stub_request(:get, oembed_url).to_return(status: 404)
      stub_request(:get, "https://www.youtube.com/embed/wC10VWDTzmU").to_return(
        status: 200,
        body: onebox_response("youtube-embed"),
      )

      onebox = Onebox::Engine::YoutubeOnebox.new(video_url)
      result = onebox.send(:parse_embed_response)

      # Should fall back but won't get data from the broken embed page
      # The fallback to get_opengraph happens in placeholder_html
      placeholder = onebox.placeholder_html
      expect(placeholder).to match(/<img/)
    end
  end
end

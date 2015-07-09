require 'spec_helper'

describe Onebox::Engine::YoutubeOnebox do
  before do
    fake("https://www.youtube.com/watch?feature=player_embedded&v=21Lk4YiASMo", response("youtube"))
    fake("https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ", response("youtube-channel"))
    fake("https://www.youtube.com/playlist?list=PL5308B2E5749D1696", response("youtube-playlist"))
  end

  it "adds wmode=opaque" do
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .to_s).to match(/wmode=opaque/)
  end

  it "rewrites URLs for videos to be HTTPS" do
    # match: plain HTTP and protocol agnostic
    regex = /(http:|["']\/\/)/

    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .to_s).not_to match(regex)
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .placeholder_html).not_to match(regex)
    expect(Onebox.preview('https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ')
    .to_s).not_to match(regex)
  end

  it "can onebox a channel page" do
    expect(Onebox.preview('https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ')
    .to_s).to match(/Google Chrome/)
  end

  it "can onebox a playlist" do
    pending('no opengraph on playlists, needs special handling')

    expect(Onebox.preview('https://www.youtube.com/playlist?list=PL5308B2E5749D1696')
    .to_s).to match(/Dear Sophie/)
  end

  it "does not make HTTP requests unless necessary" do
    # We haven't defined any fixture for requests associated with this ID, so if
    # any HTTP requests are made fakeweb will complain and the test will fail.
    Onebox.preview('http://www.youtube.com/watch?v=q39Ce3zDScI').to_s
  end

  it "does not fail if we cannot get the video ID from the URL" do
    # TODO this test no longer makes sense - the video ID is successfully retrieved and no fakeweb request is made
    expect(Onebox.preview('http://www.youtube.com/watch?feature=player_embedded&v=21Lk4YiASMo')
    .to_s).to match(/embed/)
  end

  it "returns an image as the placeholder" do
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .placeholder_html).to match(/<img/)
  end

  it "passes the playlist ID through" do
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&list=UUQau-O2C0kGJpR3_CHBTGbw&index=1')
    .to_s).to match(/UUQau-O2C0kGJpR3_CHBTGbw/)
  end

  it "filters out nonsense parameters" do
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&potential[]=exploit&potential[]=fun')
    .to_s).not_to match(/potential|exploit|fun/)
  end

  it "converts time strings into a &start= parameter" do
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&start=3782')
    .to_s).to match(/start=3782/)
    expect(Onebox.preview('https://www.youtube.com/watch?start=1h3m2s&v=21Lk4YiASMo')
    .to_s).to match(/start=3782/)
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&t=1h3m2s')
    .to_s).to match(/start=3782/)
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&start=1h3m2s')
    .to_s).to match(/start=3782/)
    expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo#t=1h3m2s')
    .to_s).to match(/start=3782/)
  end

  it "allows both start and end" do
    preview = expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&start=2m&end=3m').to_s)
    preview.to match(/start=120/)
    preview.to match(/end=180/)
  end

  it "permits looping videos" do
    preview = expect(Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&loop').to_s)
    preview.to match(/loop=1/)
    preview.to match(/playlist=21Lk4YiASMo/)
  end
end


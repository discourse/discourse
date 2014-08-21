require 'spec_helper'

describe Onebox::Engine::YoutubeOnebox do
  before do
    fake("http://www.youtube.com/watch?feature=player_embedded&v=21Lk4YiASMo", response("youtube"))
    fake("https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ", response("youtube-channel"))
  end

  it "adds wmode=opaque" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .to_s.should match(/wmode=opaque/)
  end

  it "rewrites URLs for videos to be HTTPS" do
    # match: plain HTTP and protocol agnostic
    regex = /(http:|["']\/\/)/

    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .to_s.should_not match(regex)
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .placeholder_html.should_not match(regex)
    Onebox.preview('https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ')
    .to_s.should_not match(regex)
  end

  it "can onebox a channel page" do
    Onebox.preview('https://www.youtube.com/channel/UCL8ZULXASCc1I_oaOT0NaOQ')
    .to_s.should match(/Google Chrome/)
  end

  it "can onebox a playlist" do
    pending('no opengraph on playlists, needs special handling')

    Onebox.preview('https://www.youtube.com/playlist?list=PL5308B2E5749D1696').to_s
  end

  it "does not make HTTP requests unless necessary" do
    # We haven't defined any fixture for requests associated with this ID, so if
    # any HTTP requests are made fakeweb will complain and the test will fail.
    Onebox.preview('http://www.youtube.com/watch?v=q39Ce3zDScI').to_s
  end

  it "does not fail if we cannot get the video ID from the URL" do
    # TODO this test no longer makes sense - the video ID is successfully retrieved and no fakeweb request is made
    Onebox.preview('http://www.youtube.com/watch?feature=player_embedded&v=21Lk4YiASMo')
    .to_s.should match(/embed/)
  end

  it "returns an image as the placeholder" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo')
    .placeholder_html.should match(/<img/)
  end

  it "passes the playlist ID through" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&list=UUQau-O2C0kGJpR3_CHBTGbw&index=1')
    .to_s.should match(/UUQau-O2C0kGJpR3_CHBTGbw/)
  end

  it "filters out nonsense parameters" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&potential[]=exploit&potential[]=fun')
    .to_s.should_not match(/potential|exploit|fun/)
  end

  it "converts time strings into a &start= parameter" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&start=3782')
    .to_s.should match(/start=3782/)
    Onebox.preview('https://www.youtube.com/watch?start=1h3m2s&v=21Lk4YiASMo')
    .to_s.should match(/start=3782/)
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&t=1h3m2s')
    .to_s.should match(/start=3782/)
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&start=1h3m2s')
    .to_s.should match(/start=3782/)
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo#t=1h3m2s')
    .to_s.should match(/start=3782/)
  end

  it "allows both start and end" do
    preview = Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&start=2m&end=3m').to_s
    preview.should match(/start=120/)
    preview.should match(/end=180/)
  end

  it "permits looping videos" do
    preview = Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo&loop').to_s
    preview.should match(/loop=1/)
    preview.should match(/playlist=21Lk4YiASMo/)
  end
end


require 'rails_helper'
require 'jobs/regular/pull_hotlinked_images'

describe Jobs::PullHotlinkedImages do

  let(:image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat1.png" }

  before do
    png = Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==")
    stub_request(:get, image_url).to_return(body: png)
    stub_request(:head, image_url)
    SiteSetting.download_remote_images_to_local = true
    FastImage.expects(:size).returns([100, 100]).at_least_once
  end

  it 'replaces image src' do
    post = Fabricate(:post, raw: "<img src='http://wiki.mozilla.org/images/2/2e/Longcat1.png'>")

    Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
    post.reload

    expect(post.raw).to match(/^<img src='\/uploads/)
  end

  it 'replaces image src without protocol' do
    post = Fabricate(:post, raw: "<img src='//wiki.mozilla.org/images/2/2e/Longcat1.png'>")

    Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
    post.reload

    expect(post.raw).to match(/^<img src='\/uploads/)
  end

  describe 'onebox' do

    let(:media) { "File:Brisbane_May_2013201.jpg" }
    let(:url) { "https://commons.wikimedia.org/wiki/#{media}" }
    let(:api_url) { "https://en.wikipedia.org/w/api.php?action=query&titles=#{media}&prop=imageinfo&iilimit=50&iiprop=timestamp|user|url&iiurlwidth=500&format=json" }

    before do
      SiteSetting.queue_jobs = true
      stub_request(:get, url).to_return(body: '')
      stub_request(:head, url)
      stub_request(:get, api_url).to_return(body: "{
        \"query\": {
          \"pages\": {
            \"-1\": {
              \"title\": \"#{media}\",
              \"imageinfo\": [{
                \"thumburl\": \"#{image_url}\",
                \"url\": \"#{image_url}\",
                \"descriptionurl\": \"#{url}\"
              }]
            }
          }
        }
      }")
      stub_request(:head, api_url)
    end

    it 'replaces image src' do
      post = Fabricate(:post, raw: "#{url}")

      Jobs::ProcessPost.new.execute(post_id: post.id)
      Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
      Jobs::ProcessPost.new.execute(post_id: post.id)
      post.reload

      expect(post.cooked).to match(/<img src=.*\/uploads/)
    end

  end

end

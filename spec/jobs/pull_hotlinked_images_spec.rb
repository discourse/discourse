require 'rails_helper'
require 'jobs/regular/pull_hotlinked_images'

describe Jobs::PullHotlinkedImages do

  let(:image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat1.png" }
  let(:broken_image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat2.png" }
  let(:large_image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat3.png" }
  let(:png) { Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==") }
  let(:large_png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAK10lEQVR42r3aeVRTVx4H8Oc2atWO7Sw9OnM6HWvrOON0aFlcAZ3RopZWOyqgoCACKqPWBUVQi4gIqAVllciiKPu+JOyGnQQSNgkIIQgoKljAYVARCZnf4yXhkeXlJmDP+f4hOUF+n3fvffe++y5W0i4qJqWoDU8hKQUPxWFKcq9VnHxJ8gTi5EqS0yJOtiRZfHEyJWE0i0MnJaMJTzopaQ/wpJKS0ogneTQYABANTDlDvpxBCsiu72eUP0zPq8Fzr45e8TircRDFQAAy5ABpcgDCgJV2iCbRQM+rinU/E26ie9NgfrDO1GBtTBy96SH/WhBhaxwfGEjndmfKGeiaGsYAJXIANQyCkfR05u3dhuOKVhLamnmRzocyKp9mNo9QG9IRDDiAiMaG3Nqfo45aoJROzk3DDxNCbjGahBM0yAKoDfIDOpNZE/bNYrVKJyfylB2D91pdA3lAjwE0MDAyS+BCalw9kdu2xvT6AY0NWBkJoNaAzsrj4CN1YtUTidi/hdH4BvGmJGPAAYgGMuMery/U6ONJqZ5I1PlTjNExre7kgJU/EqEbJC0gjDpiiv9hnSkJ2z+t9dzxwNcSUudlUuuxnXP+W/bZTWWO64uO6hccWQ0pPm4IP1a6GFe5bYXvNF7f0xxg3XrzgCDYjn1m4+218/D/SndaYnSqBpMDDlDXkHYnMlh7Srj+HLanxfOsyyOVN0ScYI0zkOeVZvYZGEI2/DFDMkWgTw7jAGWUA5owMOt7QtcvDF09qybA/mGC6zA7aCLVExkq9U3895/wm9LpgyonBxmDGKDQoHBySPQ8B5e/zM2kJdalN/fqxKsn8oLhFr5mdvDyX6UVNqqcpMmDAWNJACjtUMDrDVn7m6SdS/kxPwrizg+zAycLAKm5tA0a4a7DPpSFhmIAxWAgDKm0IJrutBr/g3D5n9E9J7F6oiNFGf2WtnI2vboH3YADEA0AuG2ml2i2BC4/AAYKr00uAHL/ihk0QnxQMPqKFWM/FiEamFWPYMHD8tgF1UMmZfjKZLDIJ1z/vQibzTKrbop2wAGIhoxbt8IN5zZHnoHqO5LdJr16IkXHDG4afJDJG0B8chADUAxxTnbp1trE5Z/0ASDN09hTcJdLy+EoawQZgyyAwhCxcznr0k4C0JNz5R0BYFqM3PBhQugtxKdQrEICUGFoE4ZtWPAg4jQBeJHv/Y4AkBKHdTHuZ8lP0hSDAQdQGwhAUUNv4s6/EvcfSD/T590B2u8cj3SwltkNUGaQBSgbDAXc9pxTW4jqIf8ruAa37efJLg/DfuBd21ftYU7OA387+QXSk2gHWMmRw/M2F9D2d8WffsW8Sv5+X/mtyBN7s+V2NBQasMpOEYqhuLG3MimMqL4h/GTu4fW01b/z05qrMKEGC96W+8sA8g/qKX281JuWafX350lniG++rIpOTcknb8lQGHAAoqG+pgqqr7hqE2K4kCg0bO3CJDMthvVKInTrlUmm/4j+9vO7mxYNlfrJAJiHVsYaL0g1XZy194scmy+JMCyXxWz+CAD4anTFjLrLpiMVQW+4t1G2lQiDGIBiuF/NLbmwM1B3PpQe892SFtqh4fIAhZ14mBUo34WE7ECFC29hRdDz5LO5dtrwdAGM0pP/HKoMzWsZRtwakwVQGPJjo/2/ej9Q74N8xy19o+tQYcWNzjT3mJNmR/W/uPi9fobr3ifpl6hXeG9Zge1JF5LPWvz4zYoTa7VSzu0mniggMEigNcBQ7GjE5A9Kt/eoOxLGkQBUGkoyGeEbPqnys2+OPlcbdir80PdOX+usmDFdG8OIwCc3bI0vm657WeSrsPouhuelbQZh/9nqY7FB+lsGc2ad27w86oTJo5SLrwu9s/dpVXuYFPEHELcocQC1QXpjhS4EpcMwiPhh2/U9XzfedYYFhe7UKdJSqkNOIt4oMy/uIwP68n6C3/WzMmIFHIUeJawMLm7ul9lmVdYOYgCKob6aK72NEo8yQ+UBtl99BkXoTMFcv1sF3UNaIpd24vCqvykDvCr2PbJ6GQFwNtKFrjhuCHFCCvmvcuW2ihUaMO4TWYCyAU0GSJcSsCblRTjDSJAZoFnuNiafLqReMrQlukKTylQvBZC3iikMOIDCQGaQAT9nq1gLqQRQBABFLa9U7tcTBjEApR3IALh1/DIAlQZZAIWBDOjO9HrXAMT3JliVBKCyHciALsYvAUAx4IAqOYDCmxKPBFD5QDNBQHHLS2XvfmQMYgCKgQx4muGhFmCw1B8dIOTQyvj9FO+vyDclrPqpLECZgVczBoAlA3URMCubLv6D9I657ZOP0lws1QJQv4OTGnAAogEdAF+A+TXHw3b0R5qoszLLyx4+gc8RAeUt/SrfIxIGMYDCoBDwONVdaQ9mB+3XWeK87kvJ1EYTDfYLn9XDgsdO+3NYKSACUN6FQsYAKg2IgIqgY6tnzmi6bP8y2X2EmGUbkkWCPJitV82cURfuqPq5nhPM4vchvpDGauQAygxkAMW+ULCdsfWSj/tCTr8IdeqPdBnK94FnFCEr8DXd68CyRXeObkfpRWx+D+JLdRxANlC0QwMaINHZfP37c4oczQkDnjDnvlCnMuc9RvPnxp/ehQKokAAoOlIeGUDdDvKAtsQLyv72mzJ/P6uN+rNnHtf5S7GjRVeQQ6nTbge9pdB/vEzWDso9aqoEUBuw2mciZY0gY0AEEBHEuZzZqAdFG743c/n0aQ7rtBruOKO/y+HwnyMebsABiIbG2jFAa7wryh4bPDaUXD+swWuoKv5TxMMNYgCFgQSoIgHOv7uNLbgLcfldiAc0xgAqDbVtLwTJXgQAeojmLzLKAzjBxyl257vqcgsfChUeDJA3YHUkgEpDQz2vJU7cCDJTEnQSWOHBDK0wMACgL0U7mLptXWO/fGmCk7myGW2gOra09Q36aSUcoIahc4Rfmi59JBi3H5j3k5fJOs8dhgoTYL0Jqi/1PfyMTrUKHOKGcwS9Kg9okA1iALqh+tGggBFIGJRtn2gWWEHwmlsRD5lIDdj9LpG8gXpyuN/yRJBwEQCwRYWytkEcuB28iuK2EXVPXOEAqaEW2dBUzZI+HE/wTT2RnjpGSZtQg1NjYoDa7dA50sKMIgywyTPB6l9VRbPaXmt28m0MQNEOCgdDbXu/IM17tCO5TaQjveWG1Qi6NT75htWTAOoaeA/4gnhXlF0Wiq7f3NSk1okrGQMO0NzQOdLMziU60usSPw2q7+SVlnWMlE3g1BjG6xZNxFDe1s2OO0Z0JHhxBuMBJlroUSgju682ldUxTH24QaVhDFAvB1Bp4HS+PRO/5ZDP7xtjnaXLJGKlBMtVeGqDuRk2If97z/tl0XVYZg+T3nF0F3tcjN1W2vFWrdNK8gYcgGiQvykFFl7a7oFBvG5o5UfvVRQrRuQu+mjgH5lRu7JjLPISLAtTrJ1pf94dj4U0+mhw4opsEAPU6kiEIZ1XYnZlFgFQKzu8MYtYzKYUs63E7Lnz0ls5iKeVFBrGAGq1A6uj1zZw0XZPzPwuZhqE7biiqm4vzNQP/7JVFmZbgdlxxnKienFBe4/G7YA1kADI7TDilmQJZVlE41cRirBlYdZMzIqB7UnGdseRkohZZmDW+ZhNmfibEHvuzAOcaWTD5XpLuBepdfKtiAxQ1xDPTdnhOdXUH7Nlj7uWKDnAme7bvPlI1a/Hfz4ljp+BfnqPPKD/DzQWIVWNoUiJAAAAAElFTkSuQmCC") }

  before do
    stub_request(:get, image_url).to_return(body: png, headers: { "Content-Type" => "image/png" })
    stub_request(:get, broken_image_url).to_return(status: 404)
    stub_request(:get, large_image_url).to_return(body: large_png, headers: { "Content-Type" => "image/png" })
    SiteSetting.crawl_images = true
    SiteSetting.download_remote_images_to_local = true
    SiteSetting.max_image_size_kb = 2
    SiteSetting.download_remote_images_threshold = 0
  end

  describe "#nochange" do
    it 'does saves nothing if there are no large images to pull' do
      post = Fabricate(:post, raw: 'bob bob')
      orig = post.updated_at

      freeze_time 1.week.from_now
      Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
      expect(orig).to be_within(1.second).of(post.reload.updated_at)
    end
  end

  describe '#execute' do
    before do
      SiteSetting.queue_jobs = false
      FastImage.expects(:size).returns([100, 100]).at_least_once
    end

    it 'replaces images' do
      post = Fabricate(:post, raw: "<img src='#{image_url}'>")

      Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
      post.reload

      expect(post.raw).to match(/^<img src='\/uploads/)
    end

    it 'replaces images without protocol' do
      url = image_url.sub(/^https?\:/, '')
      post = Fabricate(:post, raw: "<img src='#{url}'>")

      Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
      post.reload

      expect(post.raw).to match(/^<img src='\/uploads/)
    end

    it 'replaces images without extension' do
      url = image_url.sub(/\.[a-zA-Z0-9]+$/, '')
      stub_request(:get, url).to_return(body: png, headers: { "Content-Type" => "image/png" })
      post = Fabricate(:post, raw: "<img src='#{url}'>")

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
        stub_request(:head, url)
        stub_request(:get, url).to_return(body: '')
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
      end

      it 'replaces image src' do
        post = Fabricate(:post, raw: "#{url}")

        Jobs::ProcessPost.new.execute(post_id: post.id)
        Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
        Jobs::ProcessPost.new.execute(post_id: post.id)
        post.reload

        expect(post.cooked).to match(/<img src=.*\/uploads/)
      end

      it 'all combinations' do
        post = Fabricate(:post, raw: <<~BODY)
        <img src='#{image_url}'>
        #{url}
        <img src='#{broken_image_url}'>
        <a href='#{url}'><img src='#{large_image_url}'></a>
        BODY

        Jobs::ProcessPost.new.execute(post_id: post.id)
        Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
        Jobs::ProcessPost.new.execute(post_id: post.id)
        Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
        post.reload

        expect(post.cooked).to match(/<p><img src=.*\/uploads/)
        expect(post.cooked).to match(/<img src=.*\/uploads.*\ class="thumbnail"/)
        expect(post.cooked).to match(/<span class="broken-image/)
        expect(post.cooked).to match(/<div class="large-image-placeholder">/)
      end
    end
  end

  describe '#is_valid_image_url' do
    subject { described_class.new }

    describe 'when url is invalid' do
      it 'should return false' do
        expect(subject.is_valid_image_url("null")).to eq(false)
        expect(subject.is_valid_image_url("meta.discourse.org")).to eq(false)
      end
    end

    describe 'when url is valid' do
      it 'should return true' do
        expect(subject.is_valid_image_url("http://meta.discourse.org")).to eq(true)
        expect(subject.is_valid_image_url("//meta.discourse.org")).to eq(true)
      end
    end
  end

end

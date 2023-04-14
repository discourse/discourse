# frozen_string_literal: true

RSpec.describe "hotlinked media blocking" do
  let(:hotlinked_url) { "http://example.com/images/2/2e/Longcat1.png" }
  let(:onebox_url) { "http://example.com/onebox" }
  let(:png) do
    Base64.decode64(
      "R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==",
    )
  end

  before do
    SiteSetting.download_remote_images_to_local = false
    stub_request(:get, hotlinked_url).to_return(
      body: png,
      headers: {
        "Content-Type" => "image/png",
      },
    )
    stub_image_size
  end

  it "normally allows hotlinked images" do
    post = Fabricate(:post, raw: "<img src='#{hotlinked_url}'>")
    expect(post.cooked).to have_tag("img", with: { "src" => hotlinked_url })
  end

  context "with hotlinked media blocked, before post-processing" do
    before do
      SiteSetting.block_hotlinked_media = true
      Oneboxer.stubs(:cached_onebox).returns(
        "<aside class='onebox'><img src='#{hotlinked_url}'></aside>",
      )
    end

    it "blocks hotlinked images" do
      post = Fabricate(:post, raw: "<img src='#{hotlinked_url}'>")
      expect(post.cooked).not_to have_tag("img[src]")
      expect(post.cooked).to have_tag(
        "img",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRC_ATTR => hotlinked_url,
        },
      )
    end

    it "blocks hotlinked videos with src" do
      post = Fabricate(:post, raw: "![alt text|video](#{hotlinked_url})")
      expect(post.cooked).not_to have_tag("video source[src]")
      expect(post.cooked).to have_tag(
        "video source",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRC_ATTR => hotlinked_url,
        },
      )
    end

    it "blocks hotlinked videos with srcset" do
      srcset = "#{hotlinked_url} 1x,https://example.com 2x"
      post = Fabricate(:post, raw: "<video><source srcset='#{srcset}'></video>")
      expect(post.cooked).not_to have_tag("video source[srcset]")
      expect(post.cooked).to have_tag(
        "video source",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRCSET_ATTR => srcset,
        },
      )
    end

    it "blocks hotlinked audio" do
      post = Fabricate(:post, raw: "![alt text|audio](#{hotlinked_url})")
      expect(post.cooked).not_to have_tag("audio source[src]")
      expect(post.cooked).to have_tag(
        "audio source",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRC_ATTR => hotlinked_url,
        },
      )
    end

    it "blocks hotlinked onebox content when cached (post_analyzer)" do
      post = Fabricate(:post, raw: "#{onebox_url}")
      expect(post.cooked).not_to have_tag("img[src]")
      expect(post.cooked).to have_tag(
        "img",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRC_ATTR => hotlinked_url,
        },
      )
    end

    it "allows relative URLs" do
      src = "/assets/images/blah.png"
      post = Fabricate(:post, raw: "![](#{src})")
      expect(post.cooked).to have_tag("img", with: { src: src })
    end

    it "allows data URIs" do
      src = "data:image/png;base64,abcde"
      post = Fabricate(:post, raw: "![](#{src})")
      expect(post.cooked).to have_tag("img", with: { src: src })
    end

    it "allows an exception" do
      post = Fabricate :post, raw: <<~RAW
        ![](https://example.com)
        ![](https://example.com/myimage.png)
        ![](https://example.com.malicious.com/myimage.png)
        ![](https://malicious.invalid/https://example.com)
      RAW

      expect(post.cooked).not_to have_tag("img[src]")

      SiteSetting.block_hotlinked_media_exceptions = "https://example.com"

      post.rebake!
      post.reload
      expect(post.cooked).to have_tag("img", with: { "src" => "https://example.com" })
      expect(post.cooked).to have_tag("img", with: { "src" => "https://example.com/myimage.png" })
      expect(post.cooked).to have_tag(
        "img",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRC_ATTR => "https://example.com.malicious.com/myimage.png",
        },
      )
      expect(post.cooked).to have_tag(
        "img",
        with: {
          PrettyText::BLOCKED_HOTLINKED_SRC_ATTR => "https://malicious.invalid/https://example.com",
        },
      )
    end

    it "allows multiple exceptions" do
      post = Fabricate :post, raw: <<~RAW
        ![](https://example.com)
        ![](https://exampleb.com/myimage.png)
      RAW

      expect(post.cooked).not_to have_tag("img[src]")

      SiteSetting.block_hotlinked_media_exceptions = "https://example.com|https://exampleb.com"

      post.rebake!
      post.reload
      expect(post.cooked).to have_tag("img", with: { "src" => "https://example.com" })
      expect(post.cooked).to have_tag("img", with: { "src" => "https://exampleb.com/myimage.png" })
    end
  end

  context "with hotlinked media blocked, with post-processing" do
    before do
      SiteSetting.block_hotlinked_media = true
      Jobs.run_immediately!
      Oneboxer.stubs(:onebox).returns("<aside class='onebox'><img src='#{hotlinked_url}'></aside>")
    end

    it "renders placeholders for all media types (CookedPostProcessor)" do
      post = Fabricate :post, raw: <<~RAW
        <img src='#{hotlinked_url}'>

        ![alt text|video](#{hotlinked_url})

        ![alt text|audio](#{hotlinked_url})

        #{onebox_url}
      RAW
      post.rebake!
      post.reload
      expect(post.cooked).not_to have_tag("img")
      expect(post.cooked).not_to have_tag("video")
      expect(post.cooked).not_to have_tag("audio")
      expect(post.cooked).to have_tag(
        "a.blocked-hotlinked-placeholder[href^='http://example.com'][rel='noopener nofollow ugc']",
        count: 4,
      )
    end
  end

  context "with hotlinked media blocked, and download_remote_images_to_local enabled" do
    before do
      SiteSetting.block_hotlinked_media = true
      SiteSetting.download_remote_images_to_local = true
      Oneboxer.stubs(:onebox).returns("<aside class='onebox'><img src='#{hotlinked_url}'></aside>")
      Jobs.run_immediately!
    end

    it "can still download remote images after they're blocked" do
      post = Fabricate :post, raw: <<~RAW
        <img src='#{hotlinked_url}'>

        #{onebox_url}
      RAW
      post.rebake!
      post.reload
      expect(post.uploads.count).to eq(1)
      upload = post.uploads.first
      expect(post.cooked).to have_tag("img", count: 2)
      expect(post.cooked).to have_tag("img[src$=\"#{upload.url}\"]", count: 2)
    end
  end
end

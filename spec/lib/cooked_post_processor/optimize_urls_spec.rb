# frozen_string_literal: true

require "cooked_post_processor"
require "file_store/s3_store"

RSpec.describe CookedPostProcessor, "#optimize_urls" do
  fab!(:upload)
  fab!(:large_image_upload)
  fab!(:user_with_auto_groups) { Fabricate(:user, refresh_auto_groups: true) }
  let(:upload_path) { Discourse.store.upload_path }

  let(:post) { build(:post_with_uploads_and_links) }
  let(:cpp) { CookedPostProcessor.new(post) }

  it "uses schemaless url for uploads" do
    cpp.optimize_urls
    expect(cpp.html).to match_html <<~HTML
        <p><a href="//test.localhost/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
        <img src="//test.localhost/#{upload_path}/original/1X/1234567890123456.jpg"><br>
        <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
        <img src="http://foo.bar/image.png"><br>
        <a class="attachment" href="//test.localhost/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
        <img src="//test.localhost/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
      HTML
  end

  context "when CDN is enabled" do
    it "uses schemaless CDN url for http uploads" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      cpp.optimize_urls
      expect(cpp.html).to match_html <<~HTML
          <p><a href="//my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="//my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="//my.cdn.com/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="//my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
    end

    it "doesn't use schemaless CDN url for https uploads" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("https://my.cdn.com")
      cpp.optimize_urls
      expect(cpp.html).to match_html <<~HTML
          <p><a href="https://my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="https://my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="https://my.cdn.com/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="https://my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
    end

    it "doesn't use CDN when login is required" do
      SiteSetting.login_required = true
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      cpp.optimize_urls
      expect(cpp.html).to match_html <<~HTML
          <p><a href="//my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="//my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="//test.localhost/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="//my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
    end

    it "doesn't use CDN when preventing anons from downloading files" do
      SiteSetting.prevent_anons_from_downloading_files = true
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      cpp.optimize_urls
      expect(cpp.html).to match_html <<~HTML
          <p><a href="//my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="//my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="//test.localhost/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="//my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
    end

    context "with s3_uploads" do
      before do
        Rails.configuration.action_controller.stubs(:asset_host).returns("https://local.cdn.com")

        setup_s3
        SiteSetting.s3_cdn_url = "https://s3.cdn.com"
        SiteSetting.authorized_extensions = "png|jpg|gif|mov|ogg|"

        uploaded_file = file_from_fixtures("smallest.png")
        upload_sha1 = Digest::SHA1.hexdigest(File.read(uploaded_file))

        upload.update!(
          original_filename: "smallest.png",
          width: 10,
          height: 20,
          sha1: upload_sha1,
          extension: "png",
        )
      end

      it "uses the right CDN when uploads are on S3" do
        stored_path = Discourse.store.get_path_for_upload(upload)
        upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")

        the_post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw:
              %Q{This post has a local emoji :+1: and an external upload\n\n![smallest.png|10x20](#{upload.short_url})},
          )

        cpp = CookedPostProcessor.new(the_post)
        cpp.optimize_urls

        expect(cpp.html).to match_html <<~HTML
            <p>This post has a local emoji <img src="https://local.cdn.com/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}" title=":+1:" class="emoji" alt=":+1:" loading="lazy" width="20" height="20"> and an external upload</p>
            <p><img src="https://s3.cdn.com/#{stored_path}" alt="smallest.png" data-base62-sha1="#{upload.base62_sha1}" width="10" height="20"></p>
          HTML
      end

      it "doesn't use CDN for secure uploads" do
        SiteSetting.secure_uploads = true

        stored_path = Discourse.store.get_path_for_upload(upload)
        upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")
        upload.update_column(:secure, true)

        the_post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw:
              %Q{This post has a local emoji :+1: and an external upload\n\n![smallest.png|10x20](#{upload.short_url})},
          )

        cpp = CookedPostProcessor.new(the_post)
        cpp.optimize_urls

        expect(cpp.html).to match_html <<~HTML
            <p>This post has a local emoji <img src="https://local.cdn.com/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}" title=":+1:" class="emoji" alt=":+1:" loading="lazy" width="20" height="20"> and an external upload</p>
            <p><img src="/secure-uploads/#{stored_path}" alt="smallest.png" data-base62-sha1="#{upload.base62_sha1}" width="10" height="20"></p>
          HTML
      end

      it "doesn't use the secure uploads URL for custom emoji" do
        CustomEmoji.create!(name: "trout", upload: upload)
        Emoji.clear_cache
        Emoji.load_custom
        stored_path = Discourse.store.get_path_for_upload(upload)
        upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")
        upload.update_column(:secure, true)

        the_post =
          Fabricate(:post, user: user_with_auto_groups, raw: "This post has a custom emoji :trout:")
        the_post.cook(the_post.raw)

        cpp = CookedPostProcessor.new(the_post)
        cpp.optimize_urls

        upload_url = upload.url.gsub(SiteSetting.Upload.absolute_base_url, "https://s3.cdn.com")
        expect(cpp.html).to match_html <<~HTML
            <p>This post has a custom emoji <img src="#{upload_url}?v=#{Emoji::EMOJI_VERSION}" title=":trout:" class="emoji emoji-custom" alt=":trout:" loading="lazy" width="20" height="20"></p>
          HTML
      end

      context "with media uploads" do
        fab!(:image_upload, :upload)
        fab!(:audio_upload) { Fabricate(:upload, extension: "ogg") }
        fab!(:video_upload) { Fabricate(:upload, extension: "mov") }

        before do
          video_upload.update!(
            url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(video_upload)}",
          )
          stub_request(:head, video_upload.url)
        end

        it "ignores prevent_anons_from_downloading_files and oneboxes video uploads" do
          SiteSetting.prevent_anons_from_downloading_files = true

          the_post =
            Fabricate(
              :post,
              user: user_with_auto_groups,
              raw: "This post has an S3 video onebox:\n#{video_upload.url}",
            )

          cpp = CookedPostProcessor.new(the_post.reload)
          cpp.post_process_oneboxes

          expect(cpp.html).to match_html <<~HTML
              <p>This post has an S3 video onebox:</p>
              <div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{video_upload.url}">
                  <a href="#{video_upload.url}" rel="nofollow ugc noopener">#{video_upload.url}</a>
                </video>
              </div>
            HTML
        end

        it "oneboxes video using secure url when secure_uploads is enabled" do
          SiteSetting.login_required = true
          SiteSetting.secure_uploads = true
          video_upload.update_column(:secure, true)

          the_post =
            Fabricate(
              :post,
              user: user_with_auto_groups,
              raw: "This post has an S3 video onebox:\n#{video_upload.url}",
            )

          cpp = CookedPostProcessor.new(the_post)
          cpp.post_process_oneboxes

          secure_url =
            video_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-uploads")

          expect(cpp.html).to match_html <<~HTML
              <p>This post has an S3 video onebox:</p><div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{secure_url}">
                  <a href="#{secure_url}">#{secure_url}</a>
                </video>
              </div>
            HTML
        end

        it "oneboxes only audio/video and not images when secure_uploads is enabled" do
          SiteSetting.login_required = true
          SiteSetting.secure_uploads = true

          video_upload.update_column(:secure, true)

          audio_upload.update!(
            url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(audio_upload)}",
            secure: true,
          )

          image_upload.update!(
            url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(image_upload)}",
            secure: true,
          )

          stub_request(:head, audio_upload.url)
          stub_request(:get, image_upload.url)

          raw = <<~RAW.rstrip
              This post has a video upload.
              #{video_upload.url}

              This post has an audio upload.
              #{audio_upload.url}

              And an image upload.
              ![logo.png](upload://#{image_upload.base62_sha1}.#{image_upload.extension})
            RAW

          the_post = Fabricate(:post, user: user_with_auto_groups, raw: raw)

          cpp = CookedPostProcessor.new(the_post)
          cpp.post_process_oneboxes

          secure_video_url =
            video_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-uploads")
          secure_audio_url =
            audio_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-uploads")

          expect(cpp.html).to match_html <<~HTML
              <p>This post has a video upload.</p><div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{secure_video_url}">
                  <a href="#{secure_video_url}">
                    #{secure_video_url}
                  </a>
                </video>
              </div>

              <p>This post has an audio upload.<br>
              <audio controls="">
                <source src="#{secure_audio_url}">
                <a href="#{secure_audio_url}">
                  #{secure_audio_url}
                </a>
              </audio>
              </p>
              <p>And an image upload.<br>
              <img src="#{image_upload.url}" alt="#{image_upload.original_filename}" data-base62-sha1="#{image_upload.base62_sha1}"></p>
            HTML
        end
      end
    end
  end
end

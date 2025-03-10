# frozen_string_literal: true

RSpec.describe Jobs::PullHotlinkedImages do
  let(:image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat1.gif" }
  let(:broken_image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat2.png" }
  let(:large_image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat3.png" }
  let(:encoded_image_url) { "https://example.com/אלחוט-.jpg" }
  let(:gif) do
    Base64.decode64(
      "R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==",
    )
  end
  let(:large_png) do
    Base64.decode64(
      "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",
    )
  end
  let(:upload_path) { Discourse.store.upload_path }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before do
    Jobs.run_immediately!

    stub_request(:get, image_url).to_return(body: gif, headers: { "Content-Type" => "image/gif" })
    stub_request(:get, encoded_image_url).to_return(
      body: gif,
      headers: {
        "Content-Type" => "image/gif",
      },
    )
    stub_request(:get, broken_image_url).to_return(status: 404)
    stub_request(:get, large_image_url).to_return(
      body: large_png,
      headers: {
        "Content-Type" => "image/png",
      },
    )

    stub_request(
      :get,
      "#{Discourse.base_url}/#{upload_path}/original/1X/f59ea56fe8ebe42048491d43a19d9f34c5d0f8dc.gif",
    )

    stub_request(
      :get,
      "#{Discourse.base_url}/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png",
    )

    SiteSetting.download_remote_images_to_local = true
    SiteSetting.max_image_size_kb = 2
    SiteSetting.download_remote_images_threshold = 0
  end

  describe "#execute" do
    before { Jobs.run_immediately! }

    it "does nothing if topic has been deleted" do
      post = Fabricate(:post, user: user, raw: "<img src='#{image_url}'>")
      post.topic.destroy!

      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.not_to change {
        Upload.count
      }
    end

    it "does nothing if there are no large images to pull" do
      post = Fabricate(:post, user: user, raw: "bob bob")
      orig = post.updated_at

      freeze_time 1.week.from_now
      Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
      expect(orig).to eq_time(post.reload.updated_at)
    end

    it "replaces images" do
      post = Fabricate(:post, user: user, raw: "<img src='#{image_url}'>")
      stub_image_size

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
        Upload.count
      }.by(1).and not_change { UserHistory.count } # Should not add to the staff log

      expect(post.reload.raw).to eq("<img src=\"#{Upload.last.short_url}\">")
    end

    it "enqueues raw replacement job with a delay" do
      Jobs.run_later!

      post = Fabricate(:post, user: user, raw: "<img src='#{image_url}'>")
      stub_image_size

      freeze_time
      Jobs.expects(:cancel_scheduled_job).with(:update_hotlinked_raw, post_id: post.id).once
      delay = SiteSetting.editing_grace_period + 1

      expect_enqueued_with(
        job: :update_hotlinked_raw,
        args: {
          post_id: post.id,
        },
        at: Time.zone.now + delay.seconds,
      ) { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }
    end

    it "removes downloaded images when they are no longer needed" do
      post = Fabricate(:post, user: user, raw: "<img src='#{image_url}'>")
      stub_image_size
      post.rebake!
      post.reload
      expect(post.upload_references.count).to eq(1)

      post.update(raw: "Post with no images")
      post.rebake!
      post.reload
      expect(post.upload_references.count).to eq(0)
    end

    it "replaces images again after edit" do
      post = Fabricate(:post, user: user, raw: "<img src='#{image_url}'>")
      stub_image_size

      expect do post.rebake! end.to change { Upload.count }.by(1)

      expect(post.reload.raw).to eq("<img src=\"#{Upload.last.short_url}\">")

      # Post raw is updated back to the old value (e.g. by wordpress integration)
      post.update(raw: "<img src='#{image_url}'>")

      expect do post.rebake! end.not_to change { Upload.count } # We alread have the upload

      expect(post.reload.raw).to eq("<img src=\"#{Upload.last.short_url}\">")
    end

    it "replaces encoded image urls" do
      post = Fabricate(:post, user: user, raw: "<img src='#{encoded_image_url}'>")
      stub_image_size
      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.to change {
        Upload.count
      }.by(1)

      expect(post.reload.raw).to eq("<img src=\"#{Upload.last.short_url}\">")
    end

    it "replaces images in an anchor tag with weird indentation" do
      # Skipped pending https://meta.discourse.org/t/152801
      # This spec was previously passing, even though the resulting markdown was invalid
      # Now the spec has been improved, and shows the issue

      stub_request(
        :get,
        "http://test.localhost/uploads/short-url/z2QSs1KJWoj51uYhDjb6ifCzxH6.gif",
      ).to_return(status: 200, body: "")

      post = Fabricate(:post, user: user, raw: <<~MD)
      <h1></h1>
                                <a href="https://somelink.com">
                                    <img alt="somelink" src="#{image_url}">
                                </a>
      MD

      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.to change {
        Upload.count
      }.by(1)

      upload = post.uploads.last

      expect(post.reload.raw).to eq(<<~MD.chomp)
      <h1></h1>
                                <a href="https://somelink.com">
                                    <img alt="somelink" src="#{upload.short_url}">
                                </a>
      MD
    end

    it "replaces correct image URL" do
      url = image_url.sub("/2e/Longcat1.gif", "")
      post = Fabricate(:post, user: user, raw: "[Images](#{url})\n![](#{image_url})")
      stub_image_size

      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.to change {
        Upload.count
      }.by(1)

      expect(post.reload.raw).to eq("[Images](#{url})\n![](#{Upload.last.short_url})")
    end

    it "does not replace images in code blocks", skip: "Known issue" do
      post = Fabricate(:post, user: user, raw: <<~RAW)
        ![realimage](#{image_url})
        `![codeblockimage](#{image_url})`
      RAW
      stub_image_size

      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.to change {
        Upload.count
      }.by(1)

      expect(post.reload.raw).to eq(<<~RAW)
        ![realimage](#{Upload.last.short_url})
        `![codeblockimage](#{image_url})`
      RAW
    end

    it "replaces images without protocol" do
      url = image_url.sub(/^https?\:/, "")
      post = Fabricate(:post, user: user, raw: "<img alt='test' src='#{url}'>")
      stub_image_size

      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.to change {
        Upload.count
      }.by(1)

      expect(post.reload.raw).to eq("<img alt=\"test\" src=\"#{Upload.last.short_url}\">")
    end

    it "replaces images without extension" do
      url = image_url.sub(/\.[a-zA-Z0-9]+$/, "")
      stub_request(:get, url).to_return(body: gif, headers: { "Content-Type" => "image/gif" })
      post = Fabricate(:post, user: user, raw: "<img src='#{url}'>")
      stub_image_size

      expect do Jobs::PullHotlinkedImages.new.execute(post_id: post.id) end.to change {
        Upload.count
      }.by(1)

      expect(post.reload.raw).to eq("<img src=\"#{Upload.last.short_url}\">")
    end

    it "replaces optimized images" do
      optimized_image = Fabricate(:optimized_image)
      url = "#{Discourse.base_url}#{optimized_image.url}"

      stub_request(:get, url).to_return(status: 200, body: file_from_fixtures("smallest.png"))

      post = Fabricate(:post, user: user, raw: "<img src='#{url}'>")
      stub_image_size

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
        Upload.count
      }.by(1)

      upload = Upload.last
      post.reload

      expect(post.raw).to eq("<img src=\"#{Upload.last.short_url}\">")
      expect(post.uploads).to contain_exactly(upload)
    end

    it "skips editing raw for raw_html posts" do
      raw = "<img src=\"#{image_url}\">"
      post = Fabricate(:post, user: user, raw: raw, cook_method: Post.cook_methods[:raw_html])
      stub_image_size
      expect do
        post.rebake!
        post.reload
      end.to change { Upload.count }.by(1)

      expect(post.raw).to eq(raw)
    end

    context "when secure uploads enabled for an upload that has already been downloaded and exists" do
      it "doesnt redownload the secure upload" do
        setup_s3
        SiteSetting.secure_uploads = true

        upload = Fabricate(:secure_upload_s3, secure: true)
        stub_s3(upload)
        url = Upload.secure_uploads_url_from_upload_url(upload.url)
        url = Discourse.base_url + url
        post = Fabricate(:post, user: user, raw: "<img src='#{url}'>")
        upload.update(access_control_post: post)
        expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.not_to change {
          Upload.count
        }
      end

      context "when the upload original_sha1 is missing" do
        it "redownloads the upload" do
          setup_s3
          SiteSetting.secure_uploads = true

          upload = Fabricate(:upload_s3, secure: true)
          stub_s3(upload)
          Upload.stubs(:signed_url_from_secure_uploads_url).returns(upload.url)
          url = Upload.secure_uploads_url_from_upload_url(upload.url)
          url = Discourse.base_url + url
          post = Fabricate(:post, user: user, raw: "<img src='#{url}'>")
          upload.update(access_control_post: post)
          FileStore::S3Store.any_instance.stubs(:store_upload).returns(upload.url)

          # without this we get an infinite hang...
          Post.any_instance.stubs(:trigger_post_process)
          expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
            Upload.count
          }.by(1)
        end
      end

      context "when the upload access_control_post is different to the current post" do
        it "redownloads the upload" do
          setup_s3
          SiteSetting.secure_uploads = true

          upload = Fabricate(:secure_upload_s3, secure: true)
          stub_s3(upload)
          Upload.stubs(:signed_url_from_secure_uploads_url).returns(upload.url)
          url = Upload.secure_uploads_url_from_upload_url(upload.url)
          url = Discourse.base_url + url
          post = Fabricate(:post, user: user, raw: "<img src='#{url}'>")
          upload.update(access_control_post: Fabricate(:post))
          FileStore::S3Store.any_instance.stubs(:store_upload).returns(upload.url)

          expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
            Upload.count
          }.by(1)

          expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.not_to change {
            Upload.count
          }
        end
      end
    end

    it "replaces markdown image" do
      post = Fabricate(:post, user: user, raw: <<~MD)
      [![some test](#{image_url})](https://somelink.com)
      ![some test](#{image_url})
      ![](#{image_url})
      ![abcde](#{image_url} 'some test')
      ![](#{image_url} 'some test')
      MD
      stub_image_size

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
        Upload.count
      }.by(1)

      post.reload

      expect(post.raw).to eq(<<~MD.chomp)
      [![some test](#{Upload.last.short_url})](https://somelink.com)
      ![some test](#{Upload.last.short_url})
      ![](#{Upload.last.short_url})
      ![abcde](#{Upload.last.short_url} 'some test')
      ![](#{Upload.last.short_url} 'some test')
      MD
    end

    it "works when invalid url in post" do
      post = Fabricate(:post, user: user, raw: <<~MD)
      ![some test](#{image_url})
      ![some test 2]("#{image_url})
      MD
      stub_image_size

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
        Upload.count
      }.by(1)
    end

    it "replaces bbcode images" do
      post = Fabricate(:post, user: user, raw: <<~MD)
      [img]
      #{image_url}
      [/img]

      [img]
      #{image_url}
      [/img]
      MD
      stub_image_size

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
        Upload.count
      }.by(1)

      post.reload

      expect(post.raw).to eq(<<~MD.chomp)
      ![](#{Upload.last.short_url})

      ![](#{Upload.last.short_url})
      MD
    end

    describe "onebox" do
      let(:media) { "File:Brisbane_May_2013201.jpg" }
      let(:url) { "https://commons.wikimedia.org/wiki/#{media}" }
      let(:api_url) do
        "https://en.wikipedia.org/w/api.php?action=query&titles=#{media}&prop=imageinfo&iilimit=50&iiprop=timestamp|user|url&iiurlwidth=500&format=json"
      end

      before do
        stub_request(:head, url)
        stub_request(:get, url).to_return(body: "")
        stub_request(:head, image_url)

        stub_request(:get, api_url).to_return(
          body:
            "{
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
        }",
        )
      end

      it "replaces image src" do
        post = Fabricate(:post, user: user, raw: "#{url}")
        stub_image_size

        post.rebake!
        post.reload

        expect(post.cooked).to match(%r{<img src=.*/uploads.*\ class="thumbnail})
        expect(post.upload_references.count).to eq(1)
      end

      it "associates uploads correctly" do
        post = Fabricate(:post, user: user, raw: "#{url}")
        stub_image_size
        post.rebake!
        post.reload

        expect(post.upload_references.count).to eq(1)

        post.update(raw: "no onebox")
        post.rebake!
        post.reload

        expect(post.upload_references.count).to eq(0)
      end

      it "all combinations" do
        post = Fabricate(:post, user: user, raw: <<~MD)
        <img src='#{image_url}'>
        #{url}
        <img src='#{broken_image_url}'>
        <a href='#{url}'><img src='#{large_image_url}'></a>
        #{image_url}
        MD
        stub_image_size

        2.times { post.rebake! }

        post.reload

        expect(post.raw).to eq(<<~MD.chomp)
        <img src="upload://z2QSs1KJWoj51uYhDjb6ifCzxH6.gif">
        https://commons.wikimedia.org/wiki/File:Brisbane_May_2013201.jpg
        <img src='#{broken_image_url}'>
        <a href='#{url}'><img src='#{large_image_url}'></a>
        ![Longcat1](upload://z2QSs1KJWoj51uYhDjb6ifCzxH6.gif)
        MD

        expect(post.cooked).to match(%r{<p><img src=.*/uploads})
        expect(post.cooked).to match(%r{<img src=.*/uploads.*\ class="thumbnail})
        expect(post.cooked).to match(/<span class="broken-image/)
        expect(post.cooked).to match(/<div class="large-image-placeholder">/)
      end

      it "rewrites a lone onebox" do
        post = Fabricate(:post, user: user, raw: <<~MD)
        Onebox here:
        #{image_url}
        MD
        stub_image_size

        post.rebake!

        post.reload

        expect(post.raw).to eq(<<~MD.chomp)
        Onebox here:
        ![Longcat1](upload://z2QSs1KJWoj51uYhDjb6ifCzxH6.gif)
        MD

        expect(post.cooked).to match(%r{<img src=.*/uploads})
      end
    end
  end

  describe "#should_download_image?" do
    subject(:job) { described_class.new }

    describe "when url is invalid" do
      it "should return false" do
        expect(job.should_download_image?("null")).to eq(false)
        expect(job.should_download_image?("meta.discourse.org")).to eq(false)
      end
    end

    describe "when url is valid" do
      it "should return true" do
        expect(job.should_download_image?("http://meta.discourse.org")).to eq(true)
        expect(job.should_download_image?("//meta.discourse.org")).to eq(true)
      end
    end

    describe "when url is an upload" do
      it "should return false for original" do
        expect(job.should_download_image?(Fabricate(:upload).url)).to eq(false)
      end

      context "when secure uploads enabled" do
        it "should return false for secure-upload url" do
          setup_s3
          SiteSetting.secure_uploads = true

          upload = Fabricate(:upload_s3, secure: true)
          stub_s3(upload)
          url = Upload.secure_uploads_url_from_upload_url(upload.url)
          expect(job.should_download_image?(url)).to eq(false)
        end
      end

      it "should return true for optimized" do
        src = Discourse.store.get_path_for_optimized_image(Fabricate(:optimized_image))
        expect(job.should_download_image?(src)).to eq(true)
      end
    end

    it "returns false for emoji" do
      src = Emoji.url_for("testemoji.png")
      expect(job.should_download_image?(src)).to eq(false)
    end

    it "returns false for emoji when app and S3 CDNs configured" do
      setup_s3
      SiteSetting.s3_cdn_url = "https://s3.cdn.com"
      set_cdn_url "https://mydomain.cdn/test"

      src = UrlHelper.cook_url(Emoji.url_for("testemoji.png"))
      expect(job.should_download_image?(src)).to eq(false)
    end

    it "returns false for emoji when emoji CDN configured" do
      SiteSetting.external_emoji_url = "https://emoji.cdn.com"

      src = UrlHelper.cook_url(Emoji.url_for("testemoji.png"))
      expect(job.should_download_image?(src)).to eq(false)
    end

    it "returns false for emoji when app, S3 *and* emoji CDNs configured" do
      setup_s3
      SiteSetting.s3_cdn_url = "https://s3.cdn.com"
      SiteSetting.external_emoji_url = "https://emoji.cdn.com"
      set_cdn_url "https://mydomain.cdn/test"

      src = UrlHelper.cook_url(Emoji.url_for("testemoji.png"))
      expect(job.should_download_image?(src)).to eq(false)
    end

    it "returns false for plugin assets" do
      src = UrlHelper.cook_url("/plugins/discourse-amazing-plugin/myasset.png")
      expect(job.should_download_image?(src)).to eq(false)
    end

    it "returns false for local non-uploaded files" do
      src = UrlHelper.cook_url("/mycustomroute.png")
      expect(job.should_download_image?(src)).to eq(false)
    end

    context "when download_remote_images_to_local? is false" do
      before { SiteSetting.download_remote_images_to_local = false }

      it "still returns true for optimized" do
        src = Discourse.store.get_path_for_optimized_image(Fabricate(:optimized_image))
        expect(job.should_download_image?(src)).to eq(true)
      end

      it "returns false for valid remote URLs" do
        expect(job.should_download_image?("http://meta.discourse.org")).to eq(false)
      end
    end
  end

  describe "with a lightboxed image" do
    fab!(:upload) { Fabricate(:large_image_upload) }
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    before { Jobs.run_immediately! }

    it "replaces missing local uploads in lightbox link" do
      post =
        PostCreator.create!(
          user,
          raw: "<img src='#{Discourse.base_url}#{upload.url}'>",
          title: "Some title that is long enough",
        )

      expect(post.reload.cooked).to have_tag(:a, with: { class: "lightbox" })

      stub_request(:get, "#{Discourse.base_url}#{upload.url}").to_return(
        status: 200,
        body: file_from_fixtures("smallest.png"),
      )

      upload.delete

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.to change {
        Upload.count
      }.by(1)

      post.reload

      expect(post.raw).to eq("<img src=\"#{Upload.last.short_url}\">")
      expect(post.uploads.count).to eq(1)
    end

    it "doesn't remove optimized images from lightboxes" do
      post =
        PostCreator.create!(
          user,
          raw: "![alt](#{upload.short_url})",
          title: "Some title that is long enough",
        )

      expect(post.reload.cooked).to have_tag(:a, with: { class: "lightbox" })

      expect { Jobs::PullHotlinkedImages.new.execute(post_id: post.id) }.not_to change {
        Upload.count
      }

      post.reload

      expect(post.raw).to eq("![alt](#{upload.short_url})")
    end
  end

  describe "#disable_if_low_on_disk_space" do
    fab!(:post) { Fabricate(:post, user: user, created_at: 20.days.ago) }
    let(:job) { Jobs::PullHotlinkedImages.new }

    before do
      SiteSetting.download_remote_images_to_local = true
      SiteSetting.download_remote_images_threshold = 20
      job.stubs(:available_disk_space).returns(50)
    end

    it "does nothing when there's enough disk space" do
      SiteSetting.expects(:download_remote_images_to_local=).never
      job.execute({ post_id: post.id })
    end

    context "when there's not enough disk space" do
      before { SiteSetting.download_remote_images_threshold = 75 }

      it "disables download_remote_images_threshold and send a notification to the admin" do
        StaffActionLogger.any_instance.expects(:log_site_setting_change).once
        SystemMessage
          .expects(:create_from_system_user)
          .with(Discourse.site_contact_user, :download_remote_images_disabled)
          .once
        job.execute({ post_id: post.id })

        expect(SiteSetting.download_remote_images_to_local).to eq(false)
      end

      it "doesn't disable download_remote_images_to_local if site uses S3" do
        setup_s3
        job.execute({ post_id: post.id })

        expect(SiteSetting.download_remote_images_to_local).to eq(true)
      end
    end
  end

  def stub_s3(upload)
    stub_upload(upload)
    stub_request(:get, "https:" + upload.url).to_return(
      status: 200,
      body: file_from_fixtures("smallest.png"),
    )
  end
end

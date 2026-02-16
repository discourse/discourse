# frozen_string_literal: true

RSpec.describe UserAvatarsController do
  describe "#show_proxy_letter" do
    it "returns not found if external avatar is set somewhere else" do
      SiteSetting.external_system_avatars_url = "https://somewhere.else.com/avatar.png"
      get "/letter_avatar_proxy/v2/letter/a/aaaaaa/20.png"
      expect(response.status).to eq(404)
    end

    it "returns an avatar if we are allowing the proxy" do
      stub_request(:get, "https://avatars.discourse-cdn.com/v3/letter/a/aaaaaa/360.png").to_return(
        body: "image",
      )
      get "/letter_avatar_proxy/v3/letter/a/aaaaaa/360.png"
      expect(response.status).to eq(200)
    end
  end

  describe "#proxy_avatar cache eviction" do
    let(:proxy_path) { UserAvatarsController::PROXY_PATH }

    before { FileUtils.rm_rf(proxy_path) }

    after { FileUtils.rm_rf(proxy_path) }

    it "evicts oldest cached files in batch when the cache grows beyond the limit" do
      FileUtils.mkdir_p(proxy_path)

      old_files =
        5.times.map do |i|
          path = "#{proxy_path}/old_file_#{i}.png"
          File.write(path, "old_data_#{i}")
          path
        end
      old_files.each_with_index { |f, i| FileUtils.touch(f, mtime: Time.now - (10 - i).days) }

      stub_request(:get, "https://avatars.discourse-cdn.com/v3/letter/a/aaaaaa/360.png").to_return(
        body: "image",
      )

      stub_const(UserAvatarsController, "PROXY_CACHE_MAX_ENTRIES", 5) do
        stub_const(UserAvatarsController, "PROXY_CACHE_EVICT_COUNT", 2) do
          get "/letter_avatar_proxy/v3/letter/a/aaaaaa/360.png"
        end
      end
      expect(response.status).to eq(200)

      remaining = Dir.glob("#{proxy_path}/*")
      expect(remaining.length).to eq(4)
      expect(File.exist?(old_files[0])).to eq(false)
      expect(File.exist?(old_files[1])).to eq(false)
      expect(File.exist?(old_files[2])).to eq(true)
      expect(File.exist?(old_files[4])).to eq(true)

      new_file_sha =
        Digest::SHA1.hexdigest("https://avatars.discourse-cdn.com/v3/letter/a/aaaaaa/360.png")
      expect(File.exist?("#{proxy_path}/#{new_file_sha}.png")).to eq(true)
    end

    it "renders blank avatar when send_file fails because the cached file vanished" do
      url = "https://avatars.discourse-cdn.com/v3/letter/b/bbbbbb/360.png"
      sha = Digest::SHA1.hexdigest(url)
      path = "#{proxy_path}/#{sha}.png"

      FileUtils.mkdir_p(proxy_path)
      File.write(path, "image")

      allow_any_instance_of(UserAvatarsController).to receive(
        :send_file,
      ).and_wrap_original do |original, *args|
        raise ActionController::MissingFile, "Cannot read file #{path}" if args.first == path

        original.call(*args)
      end

      get "/letter_avatar_proxy/v3/letter/b/bbbbbb/360.png"

      expect(response.status).to eq(200)
      expect(response.headers["Last-Modified"]).to eq(Time.new(1990, 01, 01).httpdate)
    end
  end

  describe "#show" do
    context "when invalid" do
      after { FileUtils.rm(Discourse.store.path_for(upload)) }

      let :upload do
        File.open(file_from_fixtures("cropped.png")) do |f|
          UploadCreator.new(f, "test.png").create_for(-1)
        end
      end

      let(:user) do
        user = Fabricate(:user)
        user.user_avatar.update_columns(custom_upload_id: upload.id)
        user.update_columns(uploaded_avatar_id: upload.id)
        user
      end

      it "automatically corrects bad avatar extensions" do
        orig = Discourse.store.path_for(upload)

        upload.update_columns(
          original_filename: "bob.jpg",
          extension: "jpg",
          url: upload.url + ".jpg",
        )

        # at this point file is messed up
        FileUtils.mv(orig, Discourse.store.path_for(upload))

        SiteSetting.avatar_sizes = "50"

        get "/user_avatar/default/#{user.username}/50/#{upload.id}.png"

        expect(OptimizedImage.where(upload_id: upload.id).count).to eq(1)
        expect(response.status).to eq(200)

        upload.reload
        expect(upload.extension).to eq("png")
      end
    end

    it "handles non local content correctly" do
      setup_s3
      SiteSetting.avatar_sizes = "100|98|49"
      SiteSetting.unicode_usernames = true
      SiteSetting.s3_cdn_url = "http://cdn.com"

      stub_request(:get, "#{SiteSetting.s3_cdn_url}/something/else").to_return(body: "image")
      set_cdn_url("http://awesome.com/boom")

      upload =
        Fabricate(
          :upload,
          url: "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/something",
        )

      optimized_image =
        Fabricate(
          :optimized_image,
          sha1: SecureRandom.hex << "A" * 8,
          upload: upload,
          width: 98,
          height: 98,
          url:
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/something/else",
          version: OptimizedImage::VERSION,
        )

      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/97/#{upload.id}.png"

      # 98 is closest which is 49 * 2 for retina
      expect(response).to redirect_to(
        "http://awesome.com/boom/user_avatar/default/#{user.username_lower}/98/#{upload.id}_#{OptimizedImage::VERSION}.png",
      )

      get "/user_avatar/default/#{user.username}/98/#{upload.id}.png"

      expect(response.body).to eq("image")
      expect(response.headers["Cache-Control"]).to eq("max-age=31556952, public, immutable")
      expect(response.headers["Last-Modified"]).to eq(optimized_image.upload.created_at.httpdate)

      user.update!(username: "Löwe")

      get "/user_avatar/default/#{user.encoded_username}/97/#{upload.id}.png"
      expect(response).to redirect_to(
        "http://awesome.com/boom/user_avatar/default/#{user.encoded_username(lower: true)}/98/#{upload.id}_#{OptimizedImage::VERSION}.png",
      )
    end

    it "redirects to external store when enabled" do
      global_setting :redirect_avatar_requests, true
      setup_s3
      SiteSetting.avatar_sizes = "100|98|49"
      SiteSetting.s3_cdn_url = "https://s3-cdn.example.com"
      set_cdn_url("https://app-cdn.example.com")

      upload =
        Fabricate(
          :upload,
          url: "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/upload/path",
        )

      optimized_image =
        Fabricate(
          :optimized_image,
          sha1: SecureRandom.hex << "A" * 8,
          upload: upload,
          width: 98,
          height: 98,
          url:
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/optimized/path",
          version: OptimizedImage::VERSION,
        )

      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/98/#{upload.id}.png"

      expect(response.status).to eq(302)
      expect(response.location).to eq("https://s3-cdn.example.com/optimized/path")
      expect(response.headers["Cache-Control"]).to eq(
        "max-age=3600, public, immutable, stale-while-revalidate=86400",
      )
    end

    it "serves new version for old urls" do
      user = Fabricate(:user)
      SiteSetting.avatar_sizes = "45"

      image = file_from_fixtures("cropped.png")
      upload = UploadCreator.new(image, "image.png").create_for(user.id)

      user.update_columns(uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/45/#{upload.id}_1.png"

      expect(response.status).to eq(200)

      image = response.body
      optimized = upload.get_optimized_image(45, 45, {})

      expect(optimized.filesize).to eq(body.length)

      # clean up images
      upload.destroy
    end

    it "serves a correct last modified for render blank" do
      freeze_time

      get "/user_avatar/default/xxx/51/777.png"

      expect(response.status).to eq(200)

      # this image should be really old so when it is fixed various algorithms pick it up
      expect(response.headers["Last-Modified"]).to eq(Time.new(1990, 01, 01).httpdate)
    end

    it "serves image even if size missing and its in local mode" do
      SiteSetting.avatar_sizes = "50"

      upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/51/#{upload.id}.png"

      expect(response.status).to eq(200)
    end

    it "serves the correct image when the upload id changed" do
      SiteSetting.avatar_sizes = "50"
      SiteSetting.unicode_usernames = true

      upload = Fabricate(:upload)
      another_upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/50/#{another_upload.id}.png"
      expect(response).to redirect_to(
        "http://test.localhost/user_avatar/default/#{user.username_lower}/50/#{upload.id}_#{OptimizedImage::VERSION}.png",
      )

      user.update!(username: "Löwe")

      get "/user_avatar/default/#{user.encoded_username}/50/#{another_upload.id}.png"
      expect(response).to redirect_to(
        "http://test.localhost/user_avatar/default/#{user.encoded_username(lower: true)}/50/#{upload.id}_#{OptimizedImage::VERSION}.png",
      )
    end
  end
end

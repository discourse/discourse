# frozen_string_literal: true

require 'rails_helper'

describe UserAvatarsController do

  context 'show_proxy_letter' do
    it 'returns not found if external avatar is set somewhere else' do
      SiteSetting.external_system_avatars_url = "https://somewhere.else.com/avatar.png"
      get "/letter_avatar_proxy/v2/letter/a/aaaaaa/20.png"
      expect(response.status).to eq(404)
    end

    it 'returns an avatar if we are allowing the proxy' do
      stub_request(:get, "https://avatars.discourse.org/v3/letter/a/aaaaaa/360.png").to_return(body: 'image')
      get "/letter_avatar_proxy/v3/letter/a/aaaaaa/360.png"
      expect(response.status).to eq(200)
    end
  end

  context 'show' do

    context 'invalid' do
      after do
        FileUtils.rm(Discourse.store.path_for(upload))
      end
      # travis is not good here, no image magick
      if !ENV["TRAVIS"]
        let :upload do
          File.open("#{Rails.root}/spec/fixtures/images/cropped.png") do |f|
            UploadCreator.new(
              f,
              "test.png"
            ).create_for(-1)
          end
        end

        let :user do
          user = Fabricate(:user)
          user.user_avatar.update_columns(custom_upload_id: upload.id)
          user.update_columns(uploaded_avatar_id: upload.id)
          user
        end

        it 'automatically corrects bad avatar extensions' do
          orig = Discourse.store.path_for(upload)

          upload.update_columns(
            original_filename: 'bob.jpg',
            extension: 'jpg',
            url: upload.url + '.jpg'
          )

          # at this point file is messed up
          FileUtils.mv(orig, Discourse.store.path_for(upload))

          SiteSetting.avatar_sizes = "50"

          get "/user_avatar/default/#{user.username}/50/#{upload.id}.png"

          expect(OptimizedImage.where(upload_id: upload.id).count).to eq(1)
          expect(response.status).to eq(200)

          upload.reload
          expect(upload.extension).to eq('png')
        end
      end

    end

    it 'handles non local content correctly' do
      SiteSetting.avatar_sizes = "100|49"
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_access_key_id = "XXX"
      SiteSetting.s3_secret_access_key = "XXX"
      SiteSetting.s3_upload_bucket = "test"
      SiteSetting.s3_cdn_url = "http://cdn.com"

      stub_request(:get, "http://cdn.com/something/else").to_return(body: 'image')

      GlobalSetting.stubs(:cdn_url).returns("http://awesome.com/boom")

      upload = Fabricate(:upload, url: "//test.s3.dualstack.us-east-1.amazonaws.com/something")

      optimized_image = Fabricate(:optimized_image,
        sha1: SecureRandom.hex << "A" * 8,
        upload: upload,
        width: 98,
        height: 98,
        url: "//test.s3.dualstack.us-east-1.amazonaws.com/something/else",
        version: OptimizedImage::VERSION
      )

      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/97/#{upload.id}.png"

      # 98 is closest which is 49 * 2 for retina
      expect(response).to redirect_to("http://awesome.com/boom/user_avatar/default/#{user.username_lower}/98/#{upload.id}_#{OptimizedImage::VERSION}.png")

      get "/user_avatar/default/#{user.username}/98/#{upload.id}.png"

      expect(response.body).to eq("image")
      expect(response.headers["Cache-Control"]).to eq('max-age=31556952, public, immutable')
      expect(response.headers["Last-Modified"]).to eq(optimized_image.upload.created_at.httpdate)
    end

    it 'serves new version for old urls' do
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

    it 'serves a correct last modified for render blank' do
      freeze_time

      get "/user_avatar/default/xxx/51/777.png"

      expect(response.status).to eq(200)

      # this image should be really old so when it is fixed various algorithms pick it up
      expect(response.headers["Last-Modified"]).to eq(Time.new('1990-01-01').httpdate)
    end

    it 'serves image even if size missing and its in local mode' do
      SiteSetting.avatar_sizes = "50"

      upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get "/user_avatar/default/#{user.username}/51/#{upload.id}.png"

      expect(response.status).to eq(200)
    end
  end
end

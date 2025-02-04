# frozen_string_literal: true

RSpec.describe UploadsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:system_user) { Discourse.system_user }

  describe "#create" do
    it "requires you to be logged in" do
      post "/uploads.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(user) }

      let(:logo_file) { file_from_fixtures("logo.png") }
      let(:logo_filename) { File.basename(logo_file) }

      let(:logo) { Rack::Test::UploadedFile.new(logo_file) }
      let(:fake_jpg) { Rack::Test::UploadedFile.new(file_from_fixtures("fake.jpg")) }
      let(:text_file) { Rack::Test::UploadedFile.new(File.new("#{Rails.root}/LICENSE.txt")) }

      context "when rate limited" do
        before { RateLimiter.enable }

        it "should return 429 response code when maximum number of uploads per minute has been exceeded for a user" do
          SiteSetting.max_uploads_per_minute = 1

          post "/uploads.json",
               params: {
                 file: Rack::Test::UploadedFile.new(logo_file),
                 upload_type: "avatar",
               }

          expect(response.status).to eq(200)

          post "/uploads.json",
               params: {
                 file: Rack::Test::UploadedFile.new(logo_file),
                 upload_type: "avatar",
               }

          expect(response.status).to eq(429)
        end
      end

      it "expects upload_type" do
        post "/uploads.json", params: { file: logo }
        expect(response.status).to eq(400)
        post "/uploads.json",
             params: {
               file: Rack::Test::UploadedFile.new(logo_file),
               upload_type: "avatar",
             }
        expect(response.status).to eq 200
        post "/uploads.json",
             params: {
               file: Rack::Test::UploadedFile.new(logo_file),
               upload_type: "avatar",
             }
        expect(response.status).to eq 200
      end

      it "accepts the type param but logs a deprecation message when used" do
        allow(Discourse).to receive(:deprecate)
        post "/uploads.json",
             params: {
               file: Rack::Test::UploadedFile.new(logo_file),
               type: "avatar",
             }
        expect(response.status).to eq 200
        expect(Discourse).to have_received(:deprecate).with(
          "the :type param of `POST /uploads` is deprecated, use the :upload_type param instead",
          since: "3.4",
          drop_from: "3.5",
        )
      end

      it "is successful with an image" do
        post "/uploads.json", params: { file: logo, upload_type: "avatar" }
        expect(response.status).to eq 200
        expect(response.parsed_body["id"]).to be_present
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(1)
      end

      it 'returns "raw" url for site settings' do
        set_cdn_url "https://awesome.com"

        upload = UploadCreator.new(logo_file, "logo.png").create_for(-1)
        logo = Rack::Test::UploadedFile.new(file_from_fixtures("logo.png"))

        post "/uploads.json",
             params: {
               file: logo,
               upload_type: "site_setting",
               for_site_setting: "true",
             }
        expect(response.status).to eq 200
        expect(response.parsed_body["url"]).to eq(upload.url)
      end

      it "returns cdn url" do
        set_cdn_url "https://awesome.com"
        post "/uploads.json", params: { file: logo, upload_type: "composer" }
        expect(response.status).to eq 200
        expect(response.parsed_body["url"]).to start_with("https://awesome.com/uploads/default/")
      end

      it "is successful with an attachment" do
        SiteSetting.authorized_extensions = "*"

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }
        expect(response.status).to eq 200

        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        id = response.parsed_body["id"]
        expect(id).to be
      end

      it "is successful with api" do
        SiteSetting.authorized_extensions = "*"
        api_key = Fabricate(:api_key, user: user).key

        url = "http://example.com/image.png"
        png = File.read(Rails.root + "spec/fixtures/images/logo.png")

        stub_request(:get, url).to_return(status: 200, body: png)

        post "/uploads.json",
             params: {
               url: url,
               upload_type: "avatar",
             },
             headers: {
               HTTP_API_KEY: api_key,
               HTTP_API_USERNAME: user.username.downcase,
             }

        json = response.parsed_body

        expect(response.status).to eq(200)
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(1)
        expect(json["id"]).to be_present
        expect(json["short_url"]).to eq("upload://qUm0DGR49PAZshIi7HxMd3cAlzn.png")
      end

      it "correctly sets retain_hours for admins" do
        sign_in(Fabricate(:admin))

        post "/uploads.json",
             params: {
               file: logo,
               retain_hours: 100,
               upload_type: "profile_background",
             }

        id = response.parsed_body["id"]
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        expect(Upload.find(id).retain_hours).to eq(100)
      end

      it "requires a file" do
        post "/uploads.json", params: { upload_type: "composer" }

        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        message = response.parsed_body
        expect(response.status).to eq 422
        expect(message["errors"]).to contain_exactly(I18n.t("upload.file_missing"))
      end

      it "properly returns errors" do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.max_attachment_size_kb = 1

        post "/uploads.json", params: { file: text_file, upload_type: "avatar" }

        expect(response.status).to eq(422)
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        errors = response.parsed_body["errors"]
        expect(errors.first).to eq(
          I18n.t("upload.attachments.too_large_humanized", max_size: "1 KB"),
        )
      end

      it "ensures user belongs to uploaded_avatars_allowed_groups when uploading an avatar" do
        SiteSetting.uploaded_avatars_allowed_groups = "13"
        post "/uploads.json", params: { file: logo, upload_type: "avatar" }
        expect(response.status).to eq(422)

        user.change_trust_level!(TrustLevel[3])

        post "/uploads.json", params: { file: logo, upload_type: "avatar" }
        expect(response.status).to eq(200)
      end

      it "ensures discourse_connect_overrides_avatar is not enabled when uploading an avatar" do
        SiteSetting.discourse_connect_overrides_avatar = true
        post "/uploads.json", params: { file: logo, upload_type: "avatar" }
        expect(response.status).to eq(422)
      end

      it "allows staff to upload any file in PM" do
        SiteSetting.authorized_extensions = "jpg"
        SiteSetting.allow_staff_to_upload_any_file_in_pm = true
        user.update_columns(moderator: true)

        post "/uploads.json",
             params: {
               file: text_file,
               upload_type: "composer",
               for_private_message: "true",
             }

        expect(response.status).to eq(200)
        id = response.parsed_body["id"]
        expect(Upload.last.id).to eq(id)
      end

      it "allows staff to upload supported images for site settings" do
        SiteSetting.authorized_extensions = ""
        user.update!(admin: true)

        post "/uploads.json",
             params: {
               file: logo,
               upload_type: "site_setting",
               for_site_setting: "true",
             }

        expect(response.status).to eq(200)
        id = response.parsed_body["id"]

        upload = Upload.last

        expect(upload.id).to eq(id)
        expect(upload.original_filename).to eq(logo_filename)
      end

      it "respects `authorized_extensions_for_staff` setting when staff upload file" do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "*"
        user.update_columns(moderator: true)

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }

        expect(response.status).to eq(200)
        data = response.parsed_body
        expect(data["id"]).to be_present
      end

      it "ignores `authorized_extensions_for_staff` setting when non-staff upload file" do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "*"

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }

        data = response.parsed_body
        expect(data["errors"].first).to eq(I18n.t("upload.unauthorized", authorized_extensions: ""))
      end

      it "returns an error when it could not determine the dimensions of an image" do
        post "/uploads.json", params: { file: fake_jpg, upload_type: "composer" }

        expect(response.status).to eq(422)
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        message = response.parsed_body["errors"]
        expect(message).to contain_exactly(I18n.t("upload.images.size_not_found"))
      end
    end

    context "when system user is logged in" do
      before { sign_in(system_user) }

      let(:text_file) { Rack::Test::UploadedFile.new(File.new("#{Rails.root}/LICENSE.txt")) }

      it "properly returns errors if system_user_max_attachment_size_kb is not set" do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.max_attachment_size_kb = 1

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }

        expect(response.status).to eq(422)
        errors = response.parsed_body["errors"]
        expect(errors.first).to eq(
          I18n.t("upload.attachments.too_large_humanized", max_size: "1 KB"),
        )
      end

      it "should accept large files if system user" do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.system_user_max_attachment_size_kb = 421_730

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }
        expect(response.status).to eq(200)
      end

      it "should fail to accept large files if system user system_user_max_attachment_size_kb setting is low" do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.max_attachment_size_kb = 1
        SiteSetting.system_user_max_attachment_size_kb = 1

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }

        expect(response.status).to eq(422)
        errors = response.parsed_body["errors"]
        expect(errors.first).to eq(
          I18n.t("upload.attachments.too_large_humanized", max_size: "1 KB"),
        )
      end

      it "should fail to accept large files if system user system_user_max_attachment_size_kb setting is low and general setting is low" do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.max_attachment_size_kb = 10
        SiteSetting.system_user_max_attachment_size_kb = 5

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }

        expect(response.status).to eq(422)
        errors = response.parsed_body["errors"]
        expect(errors.first).to eq(
          I18n.t("upload.attachments.too_large_humanized", max_size: "10 KB"),
        )
      end

      it "should fail to accept large files if attachment_size settings are low" do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.max_attachment_size_kb = 1
        SiteSetting.system_user_max_attachment_size_kb = 10

        post "/uploads.json", params: { file: text_file, upload_type: "composer" }

        expect(response.status).to eq(422)
        errors = response.parsed_body["errors"]
        expect(errors.first).to eq(
          I18n.t("upload.attachments.too_large_humanized", max_size: "10 KB"),
        )
      end
    end
  end

  def upload_file(file, folder = "images")
    fake_logo = Rack::Test::UploadedFile.new(file_from_fixtures(file, folder))
    SiteSetting.authorized_extensions = "*"
    sign_in(user)

    post "/uploads.json", params: { file: fake_logo, upload_type: "composer" }

    expect(response.status).to eq(200)

    url = response.parsed_body["url"]
    upload = Upload.get_from_url(url)
    upload
  end

  describe "#show" do
    let(:site) { "default" }
    let(:sha) { Digest::SHA1.hexdigest("discourse") }

    context "when using external storage" do
      fab!(:upload) { upload_file("small.pdf", "pdf") }

      before { setup_s3 }

      it "returns 404 " do
        upload = Fabricate(:upload_s3)
        get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"

        expect(response.response_code).to eq(404)
      end

      it "returns upload if url not migrated" do
        get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"

        expect(response.status).to eq(200)
      end
    end

    it "returns 404 when the upload doesn't exist" do
      get "/uploads/#{site}/#{sha}.pdf"
      expect(response.status).to eq(404)
    end

    it "returns 404 when the path is nil" do
      upload = upload_file("logo.png")
      upload.update_column(:url, "invalid-url")

      get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"
      expect(response.status).to eq(404)
    end

    it "uses send_file" do
      upload = upload_file("logo.png")
      get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"
      expect(response.status).to eq(200)

      expect(response.headers["Content-Disposition"]).to eq(
        %Q|attachment; filename="#{upload.original_filename}"; filename*=UTF-8''#{upload.original_filename}|,
      )
    end

    it "returns 200 when js file" do
      ActionDispatch::FileHandler.any_instance.stubs(:match?).returns(false)
      upload = upload_file("test.js", "themes")
      get upload.url
      expect(response.status).to eq(200)
    end

    it "handles image without extension" do
      SiteSetting.authorized_extensions = "*"
      upload = upload_file("image_no_extension")

      get "/uploads/#{site}/#{upload.sha1}.json"
      expect(response.status).to eq(200)
      expect(response.headers["Content-Disposition"]).to eq(
        %Q|attachment; filename="#{upload.original_filename}"; filename*=UTF-8''#{upload.original_filename}|,
      )
    end

    it "handles file without extension" do
      SiteSetting.authorized_extensions = "*"
      upload = upload_file("not_an_image")

      get "/uploads/#{site}/#{upload.sha1}.json"
      expect(response.status).to eq(200)
      expect(response.headers["Content-Disposition"]).to eq(
        %Q|attachment; filename="#{upload.original_filename}"; filename*=UTF-8''#{upload.original_filename}|,
      )
    end

    context "when user is anonymous" do
      it "returns 404" do
        upload = upload_file("small.pdf", "pdf")
        delete "/session/#{user.username}.json"

        SiteSetting.prevent_anons_from_downloading_files = true
        get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#show_short" do
    it "inlines only supported image files" do
      upload = upload_file("smallest.png")
      get upload.short_path, params: { inline: true }
      expect(response.header["Content-Type"]).to eq("image/png")
      expect(response.header["Content-Disposition"]).to include("inline;")

      upload.update!(original_filename: "test.xml")
      get upload.short_path, params: { inline: true }
      expect(response.header["Content-Type"]).to eq("application/xml")
      expect(response.header["Content-Disposition"]).to include("attachment;")
    end

    describe "local store" do
      fab!(:image_upload) { upload_file("smallest.png") }

      it "returns the right response" do
        get image_upload.short_path

        expect(response.status).to eq(200)

        expect(response.headers["Content-Disposition"]).to include(
          "attachment; filename=\"#{image_upload.original_filename}\"",
        )
      end

      it "returns the right response when `inline` param is given" do
        get "#{image_upload.short_path}?inline=1"

        expect(response.status).to eq(200)

        expect(response.headers["Content-Disposition"]).to include(
          "inline; filename=\"#{image_upload.original_filename}\"",
        )
      end

      it "returns the right response when base62 param is invalid " do
        get "/uploads/short-url/12345.png"

        expect(response.status).to eq(404)
      end

      it "returns uploads with underscore in extension correctly" do
        fake_upload = upload_file("fake.not_image")
        get fake_upload.short_path

        expect(response.status).to eq(200)
      end

      it "returns uploads with a dash and uppercase in extension correctly" do
        fake_upload = upload_file("fake.long-FileExtension")
        get fake_upload.short_path

        expect(response.status).to eq(200)
      end

      it "returns the right response when anon tries to download a file " \
           "when prevent_anons_from_downloading_files is true" do
        delete "/session/#{user.username}.json"
        SiteSetting.prevent_anons_from_downloading_files = true

        get image_upload.short_path

        expect(response.status).to eq(404)
      end
    end

    describe "s3 store" do
      let(:upload) { Fabricate(:upload_s3) }

      before { setup_s3 }

      it "should redirect to the s3 URL" do
        get upload.short_path

        expect(response).to redirect_to(upload.url)
      end

      context "when upload is secure and secure uploads enabled" do
        before do
          SiteSetting.secure_uploads = true
          upload.update(secure: true)
        end

        it "redirects to the signed_url_for_path" do
          sign_in(user)
          freeze_time
          get upload.short_path

          expect(response).to redirect_to(
            Discourse.store.signed_url_for_path(Discourse.store.get_path_for_upload(upload)),
          )
          expect(response.header["Location"]).not_to include(
            "response-content-disposition=attachment",
          )
        end

        it "respects the force download (dl) param" do
          sign_in(user)
          freeze_time
          get upload.short_path, params: { dl: "1" }
          expect(response.header["Location"]).to include("response-content-disposition=attachment")
        end

        it "has the correct caching header" do
          sign_in(user)
          get upload.short_path

          expected_max_age =
            SiteSetting.s3_presigned_get_url_expires_after_seconds -
              UploadsController::SECURE_REDIRECT_GRACE_SECONDS
          expect(expected_max_age).to be > 0 # Sanity check that the constants haven't been set to broken values

          expect(response.headers["Cache-Control"]).to eq("max-age=#{expected_max_age}, private")
        end

        it "raises invalid access if the user cannot access the upload access control post" do
          sign_in(user)
          post = Fabricate(:post)
          post.topic.change_category_to_id(
            Fabricate(:private_category, group: Fabricate(:group)).id,
          )
          upload.update(access_control_post: post)

          get upload.short_path
          expect(response.code).to eq("403")
        end
      end
    end
  end

  describe "#show_secure" do
    describe "local store" do
      fab!(:image_upload) { upload_file("smallest.png") }

      it "does not return secure uploads when using local store" do
        secure_url = image_upload.url.sub("/uploads", "/secure-uploads")
        get secure_url

        expect(response.status).to eq(404)
      end
    end

    describe "s3 store" do
      let(:upload) { Fabricate(:upload_s3) }
      let(:secure_url) { upload.url.sub(SiteSetting.Upload.absolute_base_url, "/secure-uploads") }

      before do
        setup_s3
        SiteSetting.authorized_extensions = "*"
        SiteSetting.secure_uploads = true
      end

      it "should return 404 for anonymous requests requests" do
        get secure_url
        expect(response.status).to eq(404)
      end

      it "should return signed url for legitimate request" do
        sign_in(user)
        get secure_url

        expect(response.status).to eq(302)
        expect(response.redirect_url).to match("Amz-Expires")
      end

      it "returns signed url for legitimate request with no extension" do
        upload.update!(extension: nil, url: upload.url.sub(".png", ""))
        sign_in(user)
        get secure_url

        expect(response.status).to eq(302)
        expect(response.redirect_url).to match("Amz-Expires")
        expect(response.location).not_to include(".?")
      end

      it "should return secure uploads URL when looking up urls" do
        upload.update_column(:secure, true)
        sign_in(user)

        post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
        expect(response.status).to eq(200)

        result = response.parsed_body
        expect(result[0]["url"]).to match("secure-uploads")
      end

      context "when the upload cannot be found from the URL" do
        it "returns a 404" do
          sign_in(user)
          upload.update(sha1: "test")

          get secure_url
          expect(response.status).to eq(404)
        end
      end

      context "when the access_control_post_id has been set for the upload" do
        let(:post) { Fabricate(:post) }
        let!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

        before { upload.update(access_control_post_id: post.id) }

        context "when the user is anon" do
          it "should return signed url for public posts" do
            get secure_url
            expect(response.status).to eq(302)
            expect(response.redirect_url).to match("Amz-Expires")
          end

          it "should return 403 for deleted posts" do
            post.trash!
            get secure_url
            expect(response.status).to eq(403)
          end

          context "when the user does not have access to the post via guardian" do
            before { post.topic.change_category_to_id(private_category.id) }

            it "returns a 403" do
              get secure_url
              expect(response.status).to eq(403)
            end
          end
        end

        context "when the user is logged in" do
          before { sign_in(user) }

          context "when the user has access to the post via guardian" do
            it "should return signed url for legitimate request" do
              get secure_url
              expect(response.status).to eq(302)
              expect(response.redirect_url).to match("Amz-Expires")
            end
          end

          context "when the user does not have access to the post via guardian" do
            before { post.topic.change_category_to_id(private_category.id) }

            it "returns a 403" do
              get secure_url
              expect(response.status).to eq(403)
            end
          end
        end
      end

      context "when the upload is an attachment file" do
        before { upload.update(original_filename: "test.pdf") }
        it "redirects to the signed_url_for_path" do
          sign_in(user)
          get secure_url
          expect(response.status).to eq(302)
          expect(response.redirect_url).to match("Amz-Expires")
        end

        context "when the user does not have access to the access control post via guardian" do
          let(:post) { Fabricate(:post) }
          let!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

          before do
            post.topic.change_category_to_id(private_category.id)
            upload.update(access_control_post_id: post.id)
          end

          it "returns a 403" do
            sign_in(user)
            get secure_url
            expect(response.status).to eq(403)
          end
        end

        context "when login is required and user is not signed in" do
          let(:post) { Fabricate(:post) }

          before do
            SiteSetting.login_required = true
            upload.update(access_control_post_id: post.id)
          end

          it "returns a 403" do
            get secure_url
            expect(response.status).to eq(403)
          end
        end

        context "when the prevent_anons_from_downloading_files setting is enabled and the user is anon" do
          before { SiteSetting.prevent_anons_from_downloading_files = true }

          it "returns a 404" do
            delete "/session/#{user.username}.json"
            get secure_url
            expect(response.status).to eq(404)
          end
        end
      end

      context "when secure uploads is disabled" do
        before { SiteSetting.secure_uploads = false }

        context "if the upload is secure false, meaning the ACL is probably public" do
          before { upload.update(secure: false) }

          it "should redirect to the regular show route" do
            secure_url = upload.url.sub(SiteSetting.Upload.absolute_base_url, "/secure-uploads")
            sign_in(user)
            get secure_url

            expect(response.status).to eq(302)
            expect(response.redirect_url).to eq(Discourse.store.cdn_url(upload.url))
          end
        end

        context "if the upload is secure true, meaning the ACL is probably private" do
          before { upload.update(secure: true) }

          it "should redirect to the presigned URL still otherwise we will get a 403" do
            secure_url = upload.url.sub(SiteSetting.Upload.absolute_base_url, "/secure-uploads")
            sign_in(user)
            get secure_url

            expect(response.status).to eq(302)
            expect(response.redirect_url).to match("Amz-Expires")
          end
        end
      end
    end
  end

  describe "#lookup_urls" do
    it "can look up long urls" do
      sign_in(user)
      upload = Fabricate(:upload)

      post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
      expect(response.status).to eq(200)

      result = response.parsed_body
      expect(result[0]["url"]).to eq(upload.url)
      expect(result[0]["short_path"]).to eq(upload.short_path)
    end

    describe "secure uploads" do
      let(:upload) { Fabricate(:upload_s3, secure: true) }

      before do
        setup_s3
        SiteSetting.authorized_extensions = "pdf|png"
        SiteSetting.secure_uploads = true
      end

      it "returns secure url for a secure uploads upload" do
        sign_in(user)

        post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
        expect(response.status).to eq(200)

        result = response.parsed_body
        expect(result[0]["url"]).to match("/secure-uploads")
        expect(result[0]["short_path"]).to eq(upload.short_path)
      end

      it "returns secure urls for non-media uploads" do
        upload.update!(original_filename: "not-an-image.pdf", extension: "pdf")
        sign_in(user)

        post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
        expect(response.status).to eq(200)

        result = response.parsed_body
        expect(result[0]["url"]).to match("/secure-uploads")
        expect(result[0]["short_path"]).to eq(upload.short_path)
      end
    end
  end

  describe "#metadata" do
    fab!(:upload)

    describe "when url is missing" do
      it "should return the right response" do
        post "/uploads/lookup-metadata.json"

        expect(response.status).to eq(403)
      end
    end

    describe "when not signed in" do
      it "should return the right response" do
        post "/uploads/lookup-metadata.json", params: { url: upload.url }

        expect(response.status).to eq(403)
      end
    end

    describe "when signed in" do
      before { sign_in(user) }

      describe "when url is invalid" do
        it "should return the right response" do
          post "/uploads/lookup-metadata.json", params: { url: "abc" }

          expect(response.status).to eq(404)
        end
      end

      it "should return the right response" do
        post "/uploads/lookup-metadata.json", params: { url: upload.url }

        expect(response.status).to eq(200)

        result = response.parsed_body

        expect(result["original_filename"]).to eq(upload.original_filename)
        expect(result["width"]).to eq(upload.width)
        expect(result["height"]).to eq(upload.height)
        expect(result["human_filesize"]).to eq(upload.human_filesize)
      end
    end
  end

  describe "#generate_presigned_put" do
    context "when the store is external" do
      before do
        sign_in(user)
        SiteSetting.enable_direct_s3_uploads = true
        setup_s3
      end

      it "errors if the correct params are not provided" do
        post "/uploads/generate-presigned-put.json", params: { file_name: "test.png" }
        expect(response.status).to eq(400)
        post "/uploads/generate-presigned-put.json", params: { type: "card_background" }
        expect(response.status).to eq(400)
      end

      it "generates a presigned URL and creates an external upload stub" do
        post "/uploads/generate-presigned-put.json",
             params: {
               file_name: "test.png",
               type: "card_background",
               file_size: 1024,
             }
        expect(response.status).to eq(200)

        result = response.parsed_body

        external_upload_stub =
          ExternalUploadStub.where(
            unique_identifier: result["unique_identifier"],
            original_filename: "test.png",
            created_by: user,
            upload_type: "card_background",
            filesize: 1024,
          )
        expect(external_upload_stub.exists?).to eq(true)
        expect(result["key"]).to include(FileStore::S3Store::TEMPORARY_UPLOAD_PREFIX)
        expect(result["url"]).to include(FileStore::S3Store::TEMPORARY_UPLOAD_PREFIX)
        expect(result["url"]).to include("Amz-Expires")
        expect(result["url"]).to include("dualstack")
      end

      it "includes accepted metadata in the response when provided" do
        post "/uploads/generate-presigned-put.json",
             **{
               params: {
                 file_name: "test.png",
                 file_size: 1024,
                 type: "card_background",
                 metadata: {
                   "sha1-checksum" => "testing",
                   "blah" => "wontbeincluded",
                 },
               },
             }
        expect(response.status).to eq(200)

        result = response.parsed_body
        expect(result["url"]).not_to include("&x-amz-meta-sha1-checksum=testing")
        expect(result["url"]).not_to include("&x-amz-meta-blah=wontbeincluded")
        expect(result["signed_headers"]).to eq(
          "x-amz-acl" => "private",
          "x-amz-meta-sha1-checksum" => "testing",
        )
      end

      context "when enable_s3_transfer_acceleration is true" do
        before { SiteSetting.enable_s3_transfer_acceleration = true }

        it "uses the s3-accelerate endpoint for presigned URLs" do
          post "/uploads/generate-presigned-put.json",
               **{
                 params: {
                   file_name: "test.png",
                   file_size: 1024,
                   type: "card_background",
                   metadata: {
                     "sha1-checksum" => "testing",
                     "blah" => "wontbeincluded",
                   },
                 },
               }
          expect(response.status).to eq(200)

          result = response.parsed_body
          expect(result["url"]).to include("s3-accelerate")
        end
      end

      describe "rate limiting" do
        before { RateLimiter.enable }

        it "rate limits" do
          SiteSetting.max_presigned_put_per_minute = 1

          post "/uploads/generate-presigned-put.json",
               params: {
                 file_name: "test.png",
                 type: "card_background",
                 file_size: 1024,
               }
          post "/uploads/generate-presigned-put.json",
               params: {
                 file_name: "test.png",
                 type: "card_background",
                 file_size: 1024,
               }

          expect(response.status).to eq(429)
        end
      end
    end

    context "when the store is not external" do
      before { sign_in(user) }

      it "returns 404" do
        post "/uploads/generate-presigned-put.json",
             params: {
               file_name: "test.png",
               type: "card_background",
               file_size: 1024,
             }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#create_multipart" do
    context "when the store is external" do
      let(:mock_multipart_upload_id) do
        "ibZBv_75gd9r8lH_gqXatLdxMVpAlj6CFTR.OwyF3953YdwbcQnMA2BLGn8Lx12fQNICtMw5KyteFeHw.Sjng--"
      end
      let(:test_bucket_prefix) { "test_#{ENV["TEST_ENV_NUMBER"].presence || "0"}" }

      before do
        sign_in(user)
        SiteSetting.enable_direct_s3_uploads = true
        setup_s3
      end

      it "errors if the correct params are not provided" do
        post "/uploads/create-multipart.json", params: { file_name: "test.png" }
        expect(response.status).to eq(400)
        post "/uploads/create-multipart.json", params: { upload_type: "composer" }
        expect(response.status).to eq(400)
      end

      it "returns 422 when the create request errors" do
        FileStore::S3Store
          .any_instance
          .stubs(:create_multipart)
          .raises(Aws::S3::Errors::ServiceError.new({}, "test"))
        post "/uploads/create-multipart.json",
             **{ params: { file_name: "test.png", file_size: 1024, upload_type: "composer" } }
        expect(response.status).to eq(422)
      end

      it "returns 422 when the file is an attachment and it's too big" do
        SiteSetting.max_attachment_size_kb = 1024
        post "/uploads/create-multipart.json",
             **{ params: { file_name: "test.zip", file_size: 9_999_999, upload_type: "composer" } }
        expect(response.status).to eq(422)
        expect(response.body).to include(
          I18n.t("upload.attachments.too_large_humanized", max_size: "1 MB"),
        )
      end

      it "returns 422 when the file is an gif and it's too big, since gifs cannot be resized on client" do
        SiteSetting.max_image_size_kb = 1024
        post "/uploads/create-multipart.json",
             **{ params: { file_name: "test.gif", file_size: 9_999_999, upload_type: "composer" } }
        expect(response.status).to eq(422)
        expect(response.body).to include(
          I18n.t("upload.images.too_large_humanized", max_size: "1 MB"),
        )
      end

      it "returns a sensible error if the file size is 0 bytes" do
        SiteSetting.authorized_extensions = "*"
        stub_create_multipart_request

        post "/uploads/create-multipart.json",
             **{ params: { file_name: "test.zip", file_size: 0, upload_type: "composer" } }

        expect(response.status).to eq(422)
        expect(response.body).to include(I18n.t("upload.size_zero_failure"))
      end

      def stub_create_multipart_request
        FileStore::S3Store
          .any_instance
          .stubs(:temporary_upload_path)
          .returns(
            "uploads/default/#{test_bucket_prefix}/temp/28fccf8259bbe75b873a2bd2564b778c/test.png",
          )
        create_multipart_result = <<~XML
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
        <InitiateMultipartUploadResult>
           <Bucket>s3-upload-bucket</Bucket>
           <Key>uploads/default/#{test_bucket_prefix}/temp/28fccf8259bbe75b873a2bd2564b778c/test.png</Key>
           <UploadId>#{mock_multipart_upload_id}</UploadId>
        </InitiateMultipartUploadResult>
        XML
        stub_request(
          :post,
          "https://s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/uploads/default/#{test_bucket_prefix}/temp/28fccf8259bbe75b873a2bd2564b778c/test.png?uploads",
        ).to_return({ status: 200, body: create_multipart_result })
      end

      it "creates a multipart upload and creates an external upload stub that is marked as multipart" do
        stub_create_multipart_request
        post "/uploads/create-multipart.json",
             **{ params: { file_name: "test.png", file_size: 1024, upload_type: "composer" } }

        expect(response.status).to eq(200)
        result = response.parsed_body

        external_upload_stub =
          ExternalUploadStub.where(
            unique_identifier: result["unique_identifier"],
            original_filename: "test.png",
            created_by: user,
            upload_type: "composer",
            key: result["key"],
            external_upload_identifier: mock_multipart_upload_id,
            multipart: true,
            filesize: 1024,
          )
        expect(external_upload_stub.exists?).to eq(true)
        expect(result["key"]).to include(FileStore::S3Store::TEMPORARY_UPLOAD_PREFIX)
        expect(result["external_upload_identifier"]).to eq(mock_multipart_upload_id)
        expect(result["key"]).to eq(external_upload_stub.last.key)
      end

      it "includes accepted metadata when calling the store to create_multipart, but only allowed keys" do
        stub_create_multipart_request
        FileStore::S3Store
          .any_instance
          .expects(:create_multipart)
          .with("test.png", "image/png", metadata: { "sha1-checksum" => "testing" })
          .returns({ key: "test" })

        post "/uploads/create-multipart.json",
             **{
               params: {
                 file_name: "test.png",
                 file_size: 1024,
                 upload_type: "composer",
                 metadata: {
                   "sha1-checksum" => "testing",
                   "blah" => "wontbeincluded",
                 },
               },
             }

        expect(response.status).to eq(200)
      end

      describe "rate limiting" do
        before { RateLimiter.enable }

        it "rate limits" do
          SiteSetting.max_create_multipart_per_minute = 1

          stub_create_multipart_request
          post "/uploads/create-multipart.json",
               params: {
                 file_name: "test.png",
                 upload_type: "composer",
                 file_size: 1024,
               }
          expect(response.status).to eq(200)

          post "/uploads/create-multipart.json",
               params: {
                 file_name: "test.png",
                 upload_type: "composer",
                 file_size: 1024,
               }
          expect(response.status).to eq(429)
        end
      end
    end

    context "when the store is not external" do
      before { sign_in(user) }

      it "returns 404" do
        post "/uploads/create-multipart.json",
             params: {
               file_name: "test.png",
               upload_type: "composer",
               file_size: 1024,
             }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#batch_presign_multipart_parts" do
    fab!(:mock_multipart_upload_id) do
      "ibZBv_75gd9r8lH_gqXatLdxMVpAlj6CFTR.OwyF3953YdwbcQnMA2BLGn8Lx12fQNICtMw5KyteFeHw.Sjng--"
    end
    fab!(:external_upload_stub) do
      Fabricate(
        :image_external_upload_stub,
        created_by: user,
        multipart: true,
        external_upload_identifier: mock_multipart_upload_id,
      )
    end

    context "when the store is external" do
      before do
        sign_in(user)
        SiteSetting.enable_direct_s3_uploads = true
        setup_s3
      end

      def stub_list_multipart_request
        list_multipart_result = <<~XML
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
        <ListPartsResult>
           <Bucket>s3-upload-bucket</Bucket>
           <Key>#{external_upload_stub.key}</Key>
           <UploadId>#{mock_multipart_upload_id}</UploadId>
           <PartNumberMarker>0</PartNumberMarker>
           <NextPartNumberMarker>0</NextPartNumberMarker>
           <MaxParts>1</MaxParts>
           <IsTruncated>false</IsTruncated>
           <Part>
              <ETag>test</ETag>
              <LastModified>#{Time.zone.now}</LastModified>
              <PartNumber>1</PartNumber>
              <Size>#{5.megabytes}</Size>
           </Part>
           <Initiator>
              <DisplayName>test-upload-user</DisplayName>
              <ID>arn:aws:iam::123:user/test-upload-user</ID>
           </Initiator>
           <Owner>
              <DisplayName></DisplayName>
              <ID>12345</ID>
           </Owner>
           <StorageClass>STANDARD</StorageClass>
        </ListPartsResult>
        XML
        stub_request(
          :get,
          "https://s3-upload-bucket.#{SiteSetting.enable_s3_transfer_acceleration ? "s3-accelerate.dualstack" : "s3.dualstack.us-west-1"}.amazonaws.com/#{external_upload_stub.key}?max-parts=1&uploadId=#{mock_multipart_upload_id}",
        ).to_return({ status: 200, body: list_multipart_result })
      end

      it "errors if the correct params are not provided" do
        post "/uploads/batch-presign-multipart-parts.json", params: {}
        expect(response.status).to eq(400)
      end

      it "errors if the part_numbers do not contain numbers between 1 and 10000" do
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [-1, 0, 1, 2, 3, 4],
             }
        expect(response.status).to eq(400)
        expect(response.body).to include(
          "You supplied invalid parameters to the request: Each part number should be between 1 and 10000",
        )
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [3, 4, "blah"],
             }
        expect(response.status).to eq(400)
        expect(response.body).to include(
          "You supplied invalid parameters to the request: Each part number should be between 1 and 10000",
        )
      end

      it "returns 404 when the upload stub does not exist" do
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: "unknown",
               part_numbers: [1, 2, 3],
             }
        expect(response.status).to eq(404)
      end

      it "returns 404 when the upload stub does not belong to the user" do
        external_upload_stub.update!(created_by: Fabricate(:user))
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [1, 2, 3],
             }
        expect(response.status).to eq(404)
      end

      it "returns 404 when the multipart upload does not exist" do
        FileStore::S3Store
          .any_instance
          .stubs(:list_multipart_parts)
          .raises(Aws::S3::Errors::NoSuchUpload.new("test", "test"))
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [1, 2, 3],
             }
        expect(response.status).to eq(404)
      end

      it "returns an object with the presigned URLs with the part numbers as keys" do
        stub_list_multipart_request
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [2, 3, 4],
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["presigned_urls"].keys).to eq(%w[2 3 4])
        expect(result["presigned_urls"]["2"]).to include(
          "?partNumber=2&uploadId=#{mock_multipart_upload_id}",
        )
        expect(result["presigned_urls"]["3"]).to include(
          "?partNumber=3&uploadId=#{mock_multipart_upload_id}",
        )
        expect(result["presigned_urls"]["4"]).to include(
          "?partNumber=4&uploadId=#{mock_multipart_upload_id}",
        )
      end

      it "uses dualstack endpoint for presigned URLs based on S3 region" do
        stub_list_multipart_request
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [2, 3, 4],
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["presigned_urls"]["2"]).to include("dualstack")
      end

      context "when enable_s3_transfer_acceleration is true" do
        before { SiteSetting.enable_s3_transfer_acceleration = true }

        it "uses the s3-accelerate endpoint for presigned URLs" do
          stub_list_multipart_request
          post "/uploads/batch-presign-multipart-parts.json",
               params: {
                 unique_identifier: external_upload_stub.unique_identifier,
                 part_numbers: [2, 3, 4],
               }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["presigned_urls"].keys).to eq(%w[2 3 4])
          expect(result["presigned_urls"]["2"]).to include("s3-accelerate")
        end
      end

      describe "rate limiting" do
        before { RateLimiter.enable }

        it "rate limits" do
          SiteSetting.max_batch_presign_multipart_per_minute = 1

          stub_list_multipart_request
          post "/uploads/batch-presign-multipart-parts.json",
               params: {
                 unique_identifier: external_upload_stub.unique_identifier,
                 part_numbers: [1, 2, 3],
               }

          expect(response.status).to eq(200)

          post "/uploads/batch-presign-multipart-parts.json",
               params: {
                 unique_identifier: external_upload_stub.unique_identifier,
                 part_numbers: [1, 2, 3],
               }

          expect(response.status).to eq(429)
        end
      end
    end

    context "when the store is not external" do
      before { sign_in(user) }

      it "returns 404" do
        post "/uploads/batch-presign-multipart-parts.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               part_numbers: [1, 2, 3],
             }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#complete_multipart" do
    let(:upload_base_url) do
      "https://#{SiteSetting.s3_upload_bucket}.#{SiteSetting.enable_s3_transfer_acceleration ? "s3-accelerate.dualstack" : "s3.dualstack.#{SiteSetting.s3_region}"}.amazonaws.com"
    end
    let(:mock_multipart_upload_id) do
      "ibZBv_75gd9r8lH_gqXatLdxMVpAlj6CFTR.OwyF3953YdwbcQnMA2BLGn8Lx12fQNICtMw5KyteFeHw.Sjng--"
    end
    let!(:external_upload_stub) do
      Fabricate(
        :image_external_upload_stub,
        created_by: user,
        multipart: true,
        external_upload_identifier: mock_multipart_upload_id,
      )
    end

    context "when the store is external" do
      before do
        sign_in(user)
        SiteSetting.enable_direct_s3_uploads = true
        setup_s3
      end

      def stub_list_multipart_request
        list_multipart_result = <<~XML
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
        <ListPartsResult>
           <Bucket>s3-upload-bucket</Bucket>
           <Key>#{external_upload_stub.key}</Key>
           <UploadId>#{mock_multipart_upload_id}</UploadId>
           <PartNumberMarker>0</PartNumberMarker>
           <NextPartNumberMarker>0</NextPartNumberMarker>
           <MaxParts>1</MaxParts>
           <IsTruncated>false</IsTruncated>
           <Part>
              <ETag>test</ETag>
              <LastModified>#{Time.zone.now}</LastModified>
              <PartNumber>1</PartNumber>
              <Size>#{5.megabytes}</Size>
           </Part>
           <Initiator>
              <DisplayName>test-upload-user</DisplayName>
              <ID>arn:aws:iam::123:user/test-upload-user</ID>
           </Initiator>
           <Owner>
              <DisplayName></DisplayName>
              <ID>12345</ID>
           </Owner>
           <StorageClass>STANDARD</StorageClass>
        </ListPartsResult>
        XML
        stub_request(
          :get,
          "#{upload_base_url}/#{external_upload_stub.key}?max-parts=1&uploadId=#{mock_multipart_upload_id}",
        ).to_return({ status: 200, body: list_multipart_result })
      end

      it "errors if the correct params are not provided" do
        post "/uploads/complete-multipart.json", params: {}
        expect(response.status).to eq(400)
      end

      it "errors if the part_numbers do not contain numbers between 1 and 10000" do
        stub_list_multipart_request
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: -1, etag: "test1" }],
             }
        expect(response.status).to eq(400)
        expect(response.body).to include(
          "You supplied invalid parameters to the request: Each part number should be between 1 and 10000",
        )
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: 20_001, etag: "test1" }],
             }
        expect(response.status).to eq(400)
        expect(response.body).to include(
          "You supplied invalid parameters to the request: Each part number should be between 1 and 10000",
        )
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: "blah", etag: "test1" }],
             }
        expect(response.status).to eq(400)
        expect(response.body).to include(
          "You supplied invalid parameters to the request: Each part number should be between 1 and 10000",
        )
      end

      it "errors if any of the parts objects have missing values" do
        stub_list_multipart_request
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: 1 }],
             }
        expect(response.status).to eq(400)
        expect(response.body).to include("All parts must have an etag")
      end

      it "returns 404 when the upload stub does not exist" do
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: "unknown",
               parts: [{ part_number: 1, etag: "test1" }],
             }
        expect(response.status).to eq(404)
      end

      it "returns 422 when the complete request errors" do
        FileStore::S3Store
          .any_instance
          .stubs(:complete_multipart)
          .raises(Aws::S3::Errors::ServiceError.new({}, "test"))
        stub_list_multipart_request
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: 1, etag: "test1" }],
             }
        expect(response.status).to eq(422)
      end

      it "returns 404 when the upload stub does not belong to the user" do
        external_upload_stub.update!(created_by: Fabricate(:user))
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: 1, etag: "test1" }],
             }
        expect(response.status).to eq(404)
      end

      it "returns 404 when the multipart upload does not exist" do
        FileStore::S3Store
          .any_instance
          .stubs(:list_multipart_parts)
          .raises(Aws::S3::Errors::NoSuchUpload.new("test", "test"))
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: 1, etag: "test1" }],
             }
        expect(response.status).to eq(404)
      end

      it "completes the multipart upload, creates the Upload record, and returns a serialized Upload record" do
        temp_location = "#{upload_base_url}/#{external_upload_stub.key}"
        stub_list_multipart_request
        stub_request(
          :post,
          "#{temp_location}?uploadId=#{external_upload_stub.external_upload_identifier}",
        ).with(
          body:
            "<CompleteMultipartUpload xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\"><Part><ETag>test1</ETag><PartNumber>1</PartNumber></Part><Part><ETag>test2</ETag><PartNumber>2</PartNumber></Part></CompleteMultipartUpload>",
        ).to_return(status: 200, body: <<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <CompleteMultipartUploadResult>
             <Location>#{temp_location}</Location>
             <Bucket>s3-upload-bucket</Bucket>
             <Key>#{external_upload_stub.key}</Key>
             <ETag>testfinal</ETag>
          </CompleteMultipartUploadResult>
        XML

        # all the functionality for ExternalUploadManager is already tested along
        # with stubs to S3 in its own test, we can just stub the response here
        upload = Fabricate(:upload)
        ExternalUploadManager.any_instance.stubs(:transform!).returns(upload)

        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
               parts: [{ part_number: 1, etag: "test1" }, { part_number: 2, etag: "test2" }],
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result[:upload]).to eq(JSON.parse(UploadSerializer.new(upload).to_json)[:upload])
      end

      describe "rate limiting" do
        before { RateLimiter.enable }

        it "rate limits" do
          SiteSetting.max_complete_multipart_per_minute = 1

          post "/uploads/complete-multipart.json",
               params: {
                 unique_identifier: "blah",
                 parts: [{ part_number: 1, etag: "test1" }, { part_number: 2, etag: "test2" }],
               }
          post "/uploads/complete-multipart.json",
               params: {
                 unique_identifier: "blah",
                 parts: [{ part_number: 1, etag: "test1" }, { part_number: 2, etag: "test2" }],
               }

          expect(response.status).to eq(429)
        end
      end
    end

    context "when the store is not external" do
      before { sign_in(user) }

      it "returns 404" do
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.external_upload_identifier,
               parts: [{ part_number: 1, etag: "test1" }, { part_number: 2, etag: "test2" }],
             }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#abort_multipart" do
    let(:upload_base_url) do
      "https://#{SiteSetting.s3_upload_bucket}.#{SiteSetting.enable_s3_transfer_acceleration ? "s3-accelerate.dualstack" : "s3.dualstack.#{SiteSetting.s3_region}"}.amazonaws.com"
    end
    let(:mock_multipart_upload_id) do
      "ibZBv_75gd9r8lH_gqXatLdxMVpAlj6CFTR.OwyF3953YdwbcQnMA2BLGn8Lx12fQNICtMw5KyteFeHw.Sjng--"
    end
    let!(:external_upload_stub) do
      Fabricate(
        :image_external_upload_stub,
        created_by: user,
        multipart: true,
        external_upload_identifier: mock_multipart_upload_id,
      )
    end

    context "when the store is external" do
      before do
        sign_in(user)
        SiteSetting.enable_direct_s3_uploads = true
        setup_s3
      end

      def stub_abort_request
        temp_location = "#{upload_base_url}/#{external_upload_stub.key}"
        stub_request(
          :delete,
          "#{temp_location}?uploadId=#{external_upload_stub.external_upload_identifier}",
        ).to_return(status: 200, body: "")
      end

      it "errors if the correct params are not provided" do
        post "/uploads/abort-multipart.json", params: {}
        expect(response.status).to eq(400)
      end

      it "returns 200 when the stub does not exist, assumes it has already been deleted" do
        FileStore::S3Store.any_instance.expects(:abort_multipart).never
        post "/uploads/abort-multipart.json", params: { external_upload_identifier: "unknown" }
        expect(response.status).to eq(200)
      end

      it "returns 404 when the upload stub does not belong to the user" do
        external_upload_stub.update!(created_by: Fabricate(:user))
        post "/uploads/abort-multipart.json",
             params: {
               external_upload_identifier: external_upload_stub.external_upload_identifier,
             }
        expect(response.status).to eq(404)
      end

      it "aborts the multipart upload and deletes the stub" do
        stub_abort_request

        post "/uploads/abort-multipart.json",
             params: {
               external_upload_identifier: external_upload_stub.external_upload_identifier,
             }

        expect(response.status).to eq(200)
        expect(ExternalUploadStub.exists?(id: external_upload_stub.id)).to eq(false)
      end

      it "returns 422 when the abort request errors" do
        FileStore::S3Store
          .any_instance
          .stubs(:abort_multipart)
          .raises(Aws::S3::Errors::ServiceError.new({}, "test"))
        post "/uploads/abort-multipart.json",
             params: {
               external_upload_identifier: external_upload_stub.external_upload_identifier,
             }
        expect(response.status).to eq(422)
      end
    end

    context "when the store is not external" do
      before { sign_in(user) }

      it "returns 404" do
        post "/uploads/complete-multipart.json",
             params: {
               unique_identifier: external_upload_stub.external_upload_identifier,
               parts: [{ part_number: 1, etag: "test1" }, { part_number: 2, etag: "test2" }],
             }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#complete_external_upload" do
    before { sign_in(user) }

    context "when the store is external" do
      fab!(:external_upload_stub) { Fabricate(:image_external_upload_stub, created_by: user) }
      let(:upload) { Fabricate(:upload) }

      before do
        SiteSetting.enable_direct_s3_uploads = true
        SiteSetting.enable_upload_debug_mode = true
        setup_s3
      end

      it "returns 404 when the upload stub does not exist" do
        post "/uploads/complete-external-upload.json", params: { unique_identifier: "unknown" }
        expect(response.status).to eq(404)
      end

      it "returns 404 when the upload stub does not belong to the user" do
        external_upload_stub.update!(created_by: Fabricate(:user))
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(404)
      end

      it "handles ChecksumMismatchError" do
        ExternalUploadManager
          .any_instance
          .stubs(:transform!)
          .raises(ExternalUploadManager::ChecksumMismatchError)
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("upload.checksum_mismatch_failure"),
        )
      end

      it "handles SizeMismatchError" do
        ExternalUploadManager
          .any_instance
          .stubs(:transform!)
          .raises(ExternalUploadManager::SizeMismatchError.new("expected: 10, actual: 1000"))
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("upload.size_mismatch_failure", additional_detail: "expected: 10, actual: 1000"),
        )
      end

      it "handles CannotPromoteError" do
        ExternalUploadManager
          .any_instance
          .stubs(:transform!)
          .raises(ExternalUploadManager::CannotPromoteError)
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("upload.cannot_promote_failure"))
      end

      it "handles DownloadFailedError and Aws::S3::Errors::NotFound" do
        ExternalUploadManager
          .any_instance
          .stubs(:transform!)
          .raises(ExternalUploadManager::DownloadFailedError)
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("upload.download_failure"))
        ExternalUploadManager
          .any_instance
          .stubs(:transform!)
          .raises(Aws::S3::Errors::NotFound.new("error", "not found"))
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("upload.download_failure"))
      end

      it "handles a generic upload failure" do
        ExternalUploadManager.any_instance.stubs(:transform!).raises(StandardError)
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("upload.failed"))
      end

      it "handles validation errors on the upload" do
        upload.errors.add(:base, "test error")
        ExternalUploadManager.any_instance.stubs(:transform!).returns(upload)
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(["test error"])
      end

      it "deletes the stub and returns the serialized upload when complete" do
        ExternalUploadManager.any_instance.stubs(:transform!).returns(upload)
        post "/uploads/complete-external-upload.json",
             params: {
               unique_identifier: external_upload_stub.unique_identifier,
             }
        expect(ExternalUploadStub.exists?(id: external_upload_stub.id)).to eq(false)
        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(UploadsController.serialize_upload(upload))
      end
    end

    context "when the store is not external" do
      it "returns 404" do
        post "/uploads/generate-presigned-put.json",
             params: {
               file_name: "test.png",
               type: "card_background",
             }
        expect(response.status).to eq(404)
      end
    end
  end
end

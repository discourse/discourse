# frozen_string_literal: true

require 'rails_helper'

describe UploadsController do
  fab!(:user) { Fabricate(:user) }

  describe '#create' do
    it 'requires you to be logged in' do
      post "/uploads.json"
      expect(response.status).to eq(403)
    end

    context 'logged in' do
      before do
        sign_in(user)
      end

      let(:logo) do
        Rack::Test::UploadedFile.new(file_from_fixtures("logo.png"))
      end

      let(:fake_jpg) do
        Rack::Test::UploadedFile.new(file_from_fixtures("fake.jpg"))
      end

      let(:text_file) do
        Rack::Test::UploadedFile.new(File.new("#{Rails.root}/LICENSE.txt"))
      end

      it 'expects a type' do
        post "/uploads.json", params: { file: logo }
        expect(response.status).to eq(400)
      end

      it 'is successful with an image' do
        post "/uploads.json", params: { file: logo, type: "avatar" }
        expect(response.status).to eq 200
        expect(JSON.parse(response.body)["id"]).to be_present
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(1)
      end

      it 'is successful with an attachment' do
        SiteSetting.authorized_extensions = "*"

        post "/uploads.json", params: { file: text_file, type: "composer" }
        expect(response.status).to eq 200

        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        id = JSON.parse(response.body)["id"]
        expect(id).to be
      end

      it 'is successful with api' do
        SiteSetting.authorized_extensions = "*"
        api_key = Fabricate(:api_key, user: user).key

        url = "http://example.com/image.png"
        png = File.read(Rails.root + "spec/fixtures/images/logo.png")

        stub_request(:get, url).to_return(status: 200, body: png)

        post "/uploads.json", params: { url: url, type: "avatar", api_key: api_key, api_username: user.username }

        json = ::JSON.parse(response.body)

        expect(response.status).to eq(200)
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(1)
        expect(json["id"]).to be_present
        expect(json["short_url"]).to eq("upload://qUm0DGR49PAZshIi7HxMd3cAlzn.png")
      end

      it 'correctly sets retain_hours for admins' do
        sign_in(Fabricate(:admin))

        post "/uploads.json", params: {
          file: logo,
          retain_hours: 100,
          type: "profile_background",
        }

        id = JSON.parse(response.body)["id"]
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        expect(Upload.find(id).retain_hours).to eq(100)
      end

      it 'requires a file' do
        post "/uploads.json", params: { type: "composer" }

        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        message = JSON.parse(response.body)
        expect(response.status).to eq 422
        expect(message["errors"]).to contain_exactly(I18n.t("upload.file_missing"))
      end

      it 'properly returns errors' do
        SiteSetting.authorized_extensions = "*"
        SiteSetting.max_attachment_size_kb = 1

        post "/uploads.json", params: { file: text_file, type: "avatar" }

        expect(response.status).to eq(422)
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        errors = JSON.parse(response.body)["errors"]
        expect(errors.first).to eq(I18n.t("upload.attachments.too_large", max_size_kb: 1))
      end

      it 'ensures allow_uploaded_avatars is enabled when uploading an avatar' do
        SiteSetting.allow_uploaded_avatars = false
        post "/uploads.json", params: { file: logo, type: "avatar" }
        expect(response.status).to eq(422)
      end

      it 'ensures sso_overrides_avatar is not enabled when uploading an avatar' do
        SiteSetting.sso_overrides_avatar = true
        post "/uploads.json", params: { file: logo, type: "avatar" }
        expect(response.status).to eq(422)
      end

      it 'always allows admins to upload avatars' do
        sign_in(Fabricate(:admin))
        SiteSetting.allow_uploaded_avatars = false

        post "/uploads.json", params: { file: logo, type: "avatar" }
        expect(response.status).to eq(200)
      end

      it 'allows staff to upload any file in PM' do
        SiteSetting.authorized_extensions = "jpg"
        SiteSetting.allow_staff_to_upload_any_file_in_pm = true
        user.update_columns(moderator: true)

        post "/uploads.json", params: {
          file: text_file,
          type: "composer",
          for_private_message: "true",
        }

        expect(response.status).to eq(200)
        id = JSON.parse(response.body)["id"]
        expect(Upload.last.id).to eq(id)
      end

      it 'allows staff to upload supported images for site settings' do
        SiteSetting.authorized_extensions = ''
        user.update!(admin: true)

        post "/uploads.json", params: {
          file: logo,
          type: "site_setting",
          for_site_setting: "true",
        }

        expect(response.status).to eq(200)
        id = JSON.parse(response.body)["id"]

        upload = Upload.last

        expect(upload.id).to eq(id)
        expect(upload.original_filename).to eq('logo.png')
      end

      it 'respects `authorized_extensions_for_staff` setting when staff upload file' do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "*"
        user.update_columns(moderator: true)

        post "/uploads.json", params: {
          file: text_file,
          type: "composer",
        }

        expect(response.status).to eq(200)
        data = JSON.parse(response.body)
        expect(data["id"]).to be_present
      end

      it 'ignores `authorized_extensions_for_staff` setting when non-staff upload file' do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "*"

        post "/uploads.json", params: {
          file: text_file,
          type: "composer",
        }

        data = JSON.parse(response.body)
        expect(data["errors"].first).to eq(I18n.t("upload.unauthorized", authorized_extensions: ''))
      end

      it 'returns an error when it could not determine the dimensions of an image' do
        post "/uploads.json", params: { file: fake_jpg, type: "composer" }

        expect(response.status).to eq(422)
        expect(Jobs::CreateAvatarThumbnails.jobs.size).to eq(0)
        message = JSON.parse(response.body)["errors"]
        expect(message).to contain_exactly(I18n.t("upload.images.size_not_found"))
      end
    end
  end

  def upload_file(file, folder = "images")
    fake_logo = Rack::Test::UploadedFile.new(file_from_fixtures(file, folder))
    SiteSetting.authorized_extensions = "*"
    sign_in(user)

    post "/uploads.json", params: {
      file: fake_logo,
      type: "composer",
    }

    expect(response.status).to eq(200)

    url = JSON.parse(response.body)["url"]
    upload = Upload.get_from_url(url)
    upload
  end

  describe '#show' do
    let(:site) { "default" }
    let(:sha) { Digest::SHA1.hexdigest("discourse") }

    context "when using external storage" do
      fab!(:upload) { upload_file("small.pdf", "pdf") }

      before do
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_access_key_id = "fakeid7974664"
        SiteSetting.s3_secret_access_key = "fakesecretid7974664"
      end

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

    it 'uses send_file' do
      upload = upload_file("logo.png")
      get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"
      expect(response.status).to eq(200)

      expect(response.headers["Content-Disposition"])
        .to eq(%Q|attachment; filename="logo.png"; filename*=UTF-8''logo.png|)
    end

    it 'returns 200 when js file' do
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
      expect(response.headers["Content-Disposition"])
        .to eq(%Q|attachment; filename="image_no_extension.png"; filename*=UTF-8''image_no_extension.png|)
    end

    it "handles file without extension" do
      SiteSetting.authorized_extensions = "*"
      upload = upload_file("not_an_image")

      get "/uploads/#{site}/#{upload.sha1}.json"
      expect(response.status).to eq(200)
      expect(response.headers["Content-Disposition"])
        .to eq(%Q|attachment; filename="not_an_image"; filename*=UTF-8''not_an_image|)
    end

    context "prevent anons from downloading files" do
      it "returns 404 when an anonymous user tries to download a file" do
        upload = upload_file("small.pdf", "pdf")
        delete "/session/#{user.username}.json"

        SiteSetting.prevent_anons_from_downloading_files = true
        get "/uploads/#{site}/#{upload.sha1}.#{upload.extension}"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#show_short" do
    it 'inlines only supported image files' do
      upload = upload_file("smallest.png")
      get upload.short_path, params: { inline: true }
      expect(response.header['Content-Type']).to eq('image/png')
      expect(response.header['Content-Disposition']).to include('inline;')

      upload.update!(original_filename: "test.xml")
      get upload.short_path, params: { inline: true }
      expect(response.header['Content-Type']).to eq('application/xml')
      expect(response.header['Content-Disposition']).to include('attachment;')
    end

    describe "local store" do
      fab!(:image_upload) { upload_file("smallest.png") }

      it "returns the right response" do
        get image_upload.short_path

        expect(response.status).to eq(200)

        expect(response.headers["Content-Disposition"])
          .to include("attachment; filename=\"#{image_upload.original_filename}\"")
      end

      it "returns the right response when `inline` param is given" do
        get "#{image_upload.short_path}?inline=1"

        expect(response.status).to eq(200)

        expect(response.headers["Content-Disposition"])
          .to include("inline; filename=\"#{image_upload.original_filename}\"")
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

      before do
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_access_key_id = "fakeid7974664"
        SiteSetting.s3_secret_access_key = "fakesecretid7974664"
      end

      it "should redirect to the s3 URL" do
        get upload.short_path

        expect(response).to redirect_to(upload.url)
      end

      context "when upload is secure and secure media enabled" do
        before do
          SiteSetting.secure_media = true
          upload.update(secure: true)
          stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")
        end

        it "redirects to the signed_url_for_path" do
          get upload.short_path

          expect(response).to redirect_to(Discourse.store.signed_url_for_path(Discourse.store.get_path_for_upload(upload)))
        end

        it "raises invalid access if the user cannot access the upload access control post" do
          post = Fabricate(:post)
          post.topic.change_category_to_id(Fabricate(:private_category, group: Fabricate(:group)).id)
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

      it "does not return secure media when using local store" do
        secure_url = image_upload.url.sub("/uploads", "/secure-media-uploads")
        get secure_url

        expect(response.status).to eq(404)
      end
    end

    describe "s3 store" do
      let(:upload) { Fabricate(:upload_s3) }
      let(:secure_url) { upload.url.sub(SiteSetting.Upload.absolute_base_url, "/secure-media-uploads") }

      def sign_in_and_stub_head
        sign_in(user)
        stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")
      end

      before do
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_upload_bucket = "s3-upload-bucket"
        SiteSetting.s3_access_key_id = "fakeid7974664"
        SiteSetting.s3_secret_access_key = "fakesecretid7974664"
        SiteSetting.s3_region = "us-east-1"
        SiteSetting.secure_media = true
      end

      it "should return 404 for anonymous requests requests" do
        get secure_url
        expect(response.status).to eq(404)
      end

      it "should return signed url for legitimate request" do
        sign_in_and_stub_head

        get secure_url

        expect(response.status).to eq(302)
        expect(response.redirect_url).to match("Amz-Expires")
      end

      it "should return secure media URL when looking up urls" do
        upload.update_column(:secure, true)
        sign_in(user)

        post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
        expect(response.status).to eq(200)

        result = JSON.parse(response.body)
        expect(result[0]["url"]).to match("secure-media-uploads")
      end

      context "when the upload cannot be found from the URL" do
        it "returns a 404" do
          sign_in_and_stub_head
          upload.update(sha1: 'test')

          get secure_url
          expect(response.status).to eq(404)
        end
      end

      context "when the access_control_post_id has been set for the upload" do
        let(:post) { Fabricate(:post) }
        let!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

        before do
          sign_in_and_stub_head
          upload.update(access_control_post_id: post.id)
        end

        context "when the user has access to the post via guardian" do
          it "should return signed url for legitimate request" do
            sign_in_and_stub_head
            get secure_url
            expect(response.status).to eq(302)
            expect(response.redirect_url).to match("Amz-Expires")
          end
        end

        context "when the user does not have access to the post via guardian" do
          before do
            post.topic.change_category_to_id(private_category.id)
          end

          it "returns a 403" do
            sign_in_and_stub_head
            get secure_url
            expect(response.status).to eq(403)
          end
        end
      end

      context "when secure media is disabled" do
        before do
          SiteSetting.secure_media = false
        end

        context "if the upload is secure false, meaning the ACL is probably public" do
          before do
            upload.update(secure: false)
          end

          it "should redirect to the regular show route" do
            secure_url = upload.url.sub(SiteSetting.Upload.absolute_base_url, "/secure-media-uploads")
            sign_in(user)
            stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")

            get secure_url

            expect(response.status).to eq(302)
            expect(response.redirect_url).to eq(Discourse.store.cdn_url(upload.url))
          end
        end

        context "if the upload is secure true, meaning the ACL is probably private" do
          before do
            upload.update(secure: true)
          end

          it "should redirect to the presigned URL still otherwise we will get a 403" do
            secure_url = upload.url.sub(SiteSetting.Upload.absolute_base_url, "/secure-media-uploads")
            sign_in(user)
            stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")

            get secure_url

            expect(response.status).to eq(302)
            expect(response.redirect_url).to match("Amz-Expires")
          end
        end
      end
    end
  end

  describe '#lookup_urls' do
    it 'can look up long urls' do
      sign_in(user)
      upload = Fabricate(:upload)

      post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
      expect(response.status).to eq(200)

      result = JSON.parse(response.body)
      expect(result[0]["url"]).to eq(upload.url)
      expect(result[0]["short_path"]).to eq(upload.short_path)
    end

    describe 'secure media' do
      let(:upload) { Fabricate(:upload_s3, secure: true) }

      before do
        SiteSetting.authorized_extensions = "pdf|png"
        SiteSetting.s3_upload_bucket = "s3-upload-bucket"
        SiteSetting.s3_access_key_id = "s3-access-key-id"
        SiteSetting.s3_secret_access_key = "s3-secret-access-key"
        SiteSetting.enable_s3_uploads = true
        SiteSetting.secure_media = true
      end

      it 'returns secure url for a secure media upload' do
        sign_in(user)

        post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
        expect(response.status).to eq(200)

        result = JSON.parse(response.body)
        expect(result[0]["url"]).to match("/secure-media-uploads")
        expect(result[0]["short_path"]).to eq(upload.short_path)
      end

      it 'does not return secure urls for non-media uploads' do
        upload.update!(original_filename: "not-an-image.pdf", extension: "pdf")
        sign_in(user)

        post "/uploads/lookup-urls.json", params: { short_urls: [upload.short_url] }
        expect(response.status).to eq(200)

        result = JSON.parse(response.body)
        expect(result[0]["url"]).not_to match("/secure-media-uploads")
        expect(result[0]["short_path"]).to eq(upload.short_path)
      end
    end
  end

  describe '#metadata' do
    fab!(:upload) { Fabricate(:upload) }

    describe 'when url is missing' do
      it 'should return the right response' do
        post "/uploads/lookup-metadata.json"

        expect(response.status).to eq(403)
      end
    end

    describe 'when not signed in' do
      it 'should return the right response' do
        post "/uploads/lookup-metadata.json", params: { url: upload.url }

        expect(response.status).to eq(403)
      end
    end

    describe 'when signed in' do
      before do
        sign_in(user)
      end

      describe 'when url is invalid' do
        it 'should return the right response' do
          post "/uploads/lookup-metadata.json", params: { url: 'abc' }

          expect(response.status).to eq(404)
        end
      end

      it "should return the right response" do
        post "/uploads/lookup-metadata.json", params: { url: upload.url }

        expect(response.status).to eq(200)

        result = JSON.parse(response.body)

        expect(result["original_filename"]).to eq(upload.original_filename)
        expect(result["width"]).to eq(upload.width)
        expect(result["height"]).to eq(upload.height)
        expect(result["human_filesize"]).to eq(upload.human_filesize)
      end
    end
  end
end

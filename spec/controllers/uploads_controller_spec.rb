require 'rails_helper'

describe UploadsController do

  context '.create' do

    it 'requires you to be logged in' do
      post :create, format: :json
      expect(response.status).to eq(403)
    end

    context 'logged in' do

      before { @user = log_in :user }

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
        expect do
          post :create, params: { format: :json, file: logo }
        end.to raise_error(ActionController::ParameterMissing)
      end

      it 'can look up long urls' do
        upload = Fabricate(:upload)
        post :lookup_urls, params: { short_urls: [upload.short_url], format: :json }
        result = JSON.parse(response.body)
        expect(result[0]["url"]).to eq(upload.url)
      end

      it 'is successful with an image' do
        Jobs.expects(:enqueue).with(:create_avatar_thumbnails, anything)

        post :create, params: { file: logo, type: "avatar", format: :json }

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)["id"]).to be
      end

      it 'is successful with an attachment' do
        SiteSetting.authorized_extensions = "*"

        Jobs.expects(:enqueue).never

        post :create, params: { file: text_file, type: "composer", format: :json }

        expect(response.status).to eq 200
        id = JSON.parse(response.body)["id"]
        expect(id).to be
      end

      it 'is successful with api' do
        SiteSetting.authorized_extensions = "*"
        controller.stubs(:is_api?).returns(true)

        FinalDestination.stubs(:lookup_ip).returns("1.2.3.4")

        Jobs.expects(:enqueue).with(:create_avatar_thumbnails, anything)

        url = "http://example.com/image.png"
        png = File.read(Rails.root + "spec/fixtures/images/logo.png")

        stub_request(:get, url).to_return(status: 200, body: png)

        post :create, params: { url: url, type: "avatar", format: :json }

        json = ::JSON.parse(response.body)

        expect(response.status).to eq 200
        expect(json["id"]).to be
        expect(json["short_url"]).to eq("upload://qUm0DGR49PAZshIi7HxMd3cAlzn.png")
      end

      it 'correctly sets retain_hours for admins' do
        log_in :admin
        Jobs.expects(:enqueue).with(:create_avatar_thumbnails, anything).never

        post :create, params: {
          file: logo,
          retain_hours: 100,
          type: "profile_background",
          format: :json
        }

        id = JSON.parse(response.body)["id"]
        expect(Upload.find(id).retain_hours).to eq(100)
      end

      it 'requires a file' do
        Jobs.expects(:enqueue).never

        post :create, params: { type: "composer", format: :json }

        message = JSON.parse(response.body)
        expect(response.status).to eq 422
        expect(message["errors"]).to contain_exactly(I18n.t("upload.file_missing"))
      end

      it 'properly returns errors' do
        SiteSetting.max_attachment_size_kb = 1

        Jobs.expects(:enqueue).never

        post :create, params: { file: text_file, type: "avatar", format: :json }

        expect(response.status).to eq 422
        errors = JSON.parse(response.body)["errors"]
        expect(errors).to be
      end

      it 'ensures allow_uploaded_avatars is enabled when uploading an avatar' do
        SiteSetting.allow_uploaded_avatars = false
        post :create, params: { file: logo, type: "avatar", format: :json }
        expect(response).to_not be_success
      end

      it 'ensures sso_overrides_avatar is not enabled when uploading an avatar' do
        SiteSetting.sso_overrides_avatar = true
        post :create, params: { file: logo, type: "avatar", format: :json }
        expect(response).to_not be_success
      end

      it 'allows staff to upload any file in PM' do
        SiteSetting.authorized_extensions = "jpg"
        SiteSetting.allow_staff_to_upload_any_file_in_pm = true
        @user.update_columns(moderator: true)

        post :create, params: {
          file: text_file,
          type: "composer",
          for_private_message: "true",
          format: :json
        }

        expect(response).to be_success
        id = JSON.parse(response.body)["id"]
        expect(id).to be
      end

      it 'respects `authorized_extensions_for_staff` setting when staff upload file' do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "*"
        @user.update_columns(moderator: true)

        post :create, params: {
          file: text_file,
          type: "composer",
          format: :json
        }

        expect(response).to be_success
        data = JSON.parse(response.body)
        expect(data["id"]).to be
      end

      it 'ignores `authorized_extensions_for_staff` setting when non-staff upload file' do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "*"

        post :create, params: {
          file: text_file,
          type: "composer",
          format: :json
        }

        data = JSON.parse(response.body)
        expect(data["errors"].first).to eq(I18n.t("upload.unauthorized", authorized_extensions: ''))
      end

      it 'returns an error when it could not determine the dimensions of an image' do
        Jobs.expects(:enqueue).with(:create_avatar_thumbnails, anything).never

        post :create, params: { file: fake_jpg, type: "composer", format: :json }

        expect(response.status).to eq 422
        message = JSON.parse(response.body)["errors"]
        expect(message).to contain_exactly(I18n.t("upload.images.size_not_found"))
      end

    end

  end

  context '.show' do

    let(:site) { "default" }
    let(:sha) { Digest::SHA1.hexdigest("discourse") }

    it "returns 404 when using external storage" do
      store = stub(internal?: false)
      Discourse.stubs(:store).returns(store)
      Upload.expects(:find_by).never

      get :show, params: { site: site, sha: sha, extension: "pdf" }
      expect(response.response_code).to eq(404)
    end

    it "returns 404 when the upload doesn't exist" do
      Upload.stubs(:find_by).returns(nil)

      get :show, params: { site: site, sha: sha, extension: "pdf" }
      expect(response.response_code).to eq(404)
    end

    it 'uses send_file' do
      upload = build(:upload)
      Upload.expects(:find_by).with(sha1: sha).returns(upload)

      controller.stubs(:render)
      controller.expects(:send_file)

      get :show, params: { site: site, sha: sha, extension: "zip" }
    end

    it "handles file without extension" do
      SiteSetting.authorized_extensions = "*"
      Fabricate(:upload, original_filename: "image_file", sha1: sha)
      controller.stubs(:render)
      controller.expects(:send_file)

      get :show, params: { site: site, sha: sha, format: :json }
      expect(response).to be_success
    end

    context "prevent anons from downloading files" do

      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it "returns 404 when an anonymous user tries to download a file" do
        Upload.expects(:find_by).never

        get :show, params: { site: site, sha: sha, extension: "pdf", format: :json }
        expect(response.response_code).to eq(404)
      end

    end

  end

end

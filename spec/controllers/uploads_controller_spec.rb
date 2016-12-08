require 'rails_helper'

describe UploadsController do

  context '.create' do

    it 'requires you to be logged in' do
      expect { xhr :post, :create }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'logged in' do

      before { @user = log_in :user }

      let(:logo) do
        ActionDispatch::Http::UploadedFile.new({
          filename: 'logo.png',
          tempfile: file_from_fixtures("logo.png")
        })
      end

      let(:fake_jpg) do
        ActionDispatch::Http::UploadedFile.new({
          filename: 'fake.jpg',
          tempfile: file_from_fixtures("fake.jpg")
        })
      end

      let(:text_file) do
        ActionDispatch::Http::UploadedFile.new({
          filename: 'LICENSE.TXT',
          tempfile: File.new("#{Rails.root}/LICENSE.txt")
        })
      end

      it 'is successful with an image' do
        Jobs.expects(:enqueue).with(:create_thumbnails, anything)

        message = MessageBus.track_publish do
          xhr :post, :create, file: logo, type: "avatar"
        end.first

        expect(response.status).to eq 200

        expect(message.channel).to eq("/uploads/avatar")
        expect(message.data).to be
      end

      it 'is successful with an attachment' do
        SiteSetting.stubs(:authorized_extensions).returns("*")

        Jobs.expects(:enqueue).never

        message = MessageBus.track_publish do
          xhr :post, :create, file: text_file, type: "composer"
        end.first

        expect(response.status).to eq 200
        expect(message.channel).to eq("/uploads/composer")
        expect(message.data).to be
      end

      it 'is successful with synchronous api' do
        SiteSetting.stubs(:authorized_extensions).returns("*")
        controller.stubs(:is_api?).returns(true)

        Jobs.expects(:enqueue).with(:create_thumbnails, anything)

        FakeWeb.register_uri(:get, "http://example.com/image.png", :body => File.read('spec/fixtures/images/logo.png'))

        xhr :post, :create, url: 'http://example.com/image.png', type: "avatar", synchronous: true

        json = ::JSON.parse(response.body)

        expect(response.status).to eq 200
        expect(json["id"]).to be
      end

      it 'correctly sets retain_hours for admins' do
        log_in :admin
        Jobs.expects(:enqueue).with(:create_thumbnails, anything)

        message = MessageBus.track_publish do
          xhr :post, :create, file: logo, retain_hours: 100, type: "profile_background"
        end.first

        id = message.data["id"]
        expect(Upload.find(id).retain_hours).to eq(100)
      end

      it 'requires a file' do
        Jobs.expects(:enqueue).never

        message = MessageBus.track_publish do
          xhr :post, :create, type: "composer"
        end.first

        expect(response.status).to eq 200
        expect(message.data["errors"]).to eq(I18n.t("upload.file_missing"))
      end

      it 'properly returns errors' do
        SiteSetting.stubs(:max_attachment_size_kb).returns(1)

        Jobs.expects(:enqueue).never

        message = MessageBus.track_publish do
          xhr :post, :create, file: text_file, type: "avatar"
        end.first

        expect(response.status).to eq 200
        expect(message.data["errors"]).to be
      end

      it 'ensures allow_uploaded_avatars is enabled when uploading an avatar' do
        SiteSetting.stubs(:allow_uploaded_avatars).returns(false)
        xhr :post, :create, file: logo, type: "avatar"
        expect(response).to_not be_success
      end

      it 'ensures sso_overrides_avatar is not enabled when uploading an avatar' do
        SiteSetting.stubs(:sso_overrides_avatar).returns(true)
        xhr :post, :create, file: logo, type: "avatar"
        expect(response).to_not be_success
      end

      it 'returns an error when it could not determine the dimensions of an image' do
        Jobs.expects(:enqueue).with(:create_thumbnails, anything).never

        message = MessageBus.track_publish do
          xhr :post, :create, file: fake_jpg, type: "composer"
        end.first

        expect(response.status).to eq 200

        expect(message.channel).to eq("/uploads/composer")
        expect(message.data["errors"]).to be
        expect(message.data["errors"][0]).to eq(I18n.t("upload.images.size_not_found"))
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

      get :show, site: site, sha: sha, extension: "pdf"
      expect(response.response_code).to eq(404)
    end

    it "returns 404 when the upload doens't exist" do
      Upload.stubs(:find_by).returns(nil)

      get :show, site: site, sha: sha, extension: "pdf"
      expect(response.response_code).to eq(404)
    end

    it 'uses send_file' do
      upload = build(:upload)
      Upload.expects(:find_by).with(sha1: sha).returns(upload)

      controller.stubs(:render)
      controller.expects(:send_file)

      get :show, site: site, sha: sha, extension: "zip"
    end

    context "prevent anons from downloading files" do

      before { SiteSetting.stubs(:prevent_anons_from_downloading_files).returns(true) }

      it "returns 404 when an anonymous user tries to download a file" do
        Upload.expects(:find_by).never

        get :show, site: site, sha: sha, extension: "pdf"
        expect(response.response_code).to eq(404)
      end

    end

  end

end

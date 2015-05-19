require 'spec_helper'

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

      let(:logo_dev) do
        ActionDispatch::Http::UploadedFile.new({
          filename: 'logo-dev.png',
          tempfile: file_from_fixtures("logo-dev.png")
        })
      end

      let(:text_file) do
        ActionDispatch::Http::UploadedFile.new({
          filename: 'LICENSE.TXT',
          tempfile: File.new("#{Rails.root}/LICENSE.txt")
        })
      end

      let(:files) { [ logo_dev, logo ] }

      context 'with a file' do

        context 'when authorized' do

          before { SiteSetting.stubs(:authorized_extensions).returns(".PNG|.txt") }

          it 'is successful with an image' do
            xhr :post, :create, file: logo
            expect(response.status).to eq 200
          end

          it 'is successful with an attachment' do
            xhr :post, :create, file: text_file
            expect(response.status).to eq 200
          end

          it 'correctly sets retain_hours for admins' do
            log_in :admin
            xhr :post, :create, file: logo, retain_hours: 100
            id = JSON.parse(response.body)["id"]
            expect(Upload.find(id).retain_hours).to eq(100)
          end

          context 'with a big file' do

            before { SiteSetting.stubs(:max_attachment_size_kb).returns(1) }

            it 'rejects the upload' do
              xhr :post, :create, file: text_file
              expect(response.status).to eq 422
            end

          end

        end

        context 'when not authorized' do

          before { SiteSetting.stubs(:authorized_extensions).returns(".png") }

          it 'rejects the upload' do
            xhr :post, :create, file: text_file
            expect(response.status).to eq 422
          end

        end

        context 'when everything is authorized' do

          before { SiteSetting.stubs(:authorized_extensions).returns("*") }

          it 'is successful with an image' do
            xhr :post, :create, file: logo
            expect(response.status).to eq 200
          end

          it 'is successful with an attachment' do
            xhr :post, :create, file: text_file
            expect(response.status).to eq 200
          end

        end

      end

      context 'with some files' do

        it 'is successful' do
          xhr :post, :create, files: files
          expect(response).to be_success
        end

        it 'takes the first file' do
          xhr :post, :create, files: files
          expect(response.body).to match /logo-dev.png/
        end

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
      Upload.expects(:find_by).with(sha1: sha).returns(nil)

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

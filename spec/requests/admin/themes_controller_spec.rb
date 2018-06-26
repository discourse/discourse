require 'rails_helper'
require_dependency 'theme_serializer'

describe Admin::ThemesController do
  let(:admin) { Fabricate(:admin) }

  it "is a subclass of AdminController" do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  before do
    sign_in(admin)
  end

  describe '#generate_key_pair' do
    it 'can generate key pairs' do
      post "/admin/themes/generate_key_pair.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["private_key"]).to include("RSA PRIVATE KEY")
      expect(json["public_key"]).to include("ssh-rsa ")
    end
  end

  describe '#upload_asset' do
    let(:upload) do
      Rack::Test::UploadedFile.new(file_from_fixtures("fake.woff2", "woff2"))
    end

    it 'can create a theme upload' do
      post "/admin/themes/upload_asset.json", params: { file: upload }
      expect(response.status).to eq(201)

      upload = Upload.find_by(original_filename: "fake.woff2")

      expect(upload.id).not_to be_nil
      expect(JSON.parse(response.body)["upload_id"]).to eq(upload.id)
    end
  end

  describe '#import' do
    let(:theme_file) do
      Rack::Test::UploadedFile.new(file_from_fixtures("sam-s-simple-theme.dcstyle.json", "json"))
    end

    let(:image) do
      file_from_fixtures("logo.png")
    end

    it 'can import a theme with an upload' do
      upload = Fabricate(:upload)
      theme = Theme.new(name: 'with-upload', user_id: -1)
      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      theme.set_field(target: :common, name: :logo, upload_id: upload.id, type: :theme_upload_var)
      theme.save!

      json = ThemeWithEmbeddedUploadsSerializer.new(theme, root: 'theme').to_json
      theme.destroy

      temp = Tempfile.new
      temp.write(json)
      temp.rewind

      uploaded_json = Rack::Test::UploadedFile.new(temp)
      upload.destroy

      post "/admin/themes/import.json", params: { theme: uploaded_json }
      expect(response.status).to eq(201)
      temp.unlink

      theme = Theme.last
      expect(theme.theme_fields.count).to eq(1)
      expect(theme.theme_fields.first.upload).not_to eq(nil)
      expect(theme.theme_fields.first.upload.filesize).to eq(upload.filesize)
      expect(theme.theme_fields.first.upload.sha1).to eq(upload.sha1)
      expect(theme.theme_fields.first.upload.original_filename).to eq(upload.original_filename)
    end

    it 'imports a theme' do
      post "/admin/themes/import.json", params: { theme: theme_file }
      expect(response.status).to eq(201)

      json = ::JSON.parse(response.body)

      expect(json["theme"]["name"]).to eq("Sam's Simple Theme")
      expect(json["theme"]["theme_fields"].length).to eq(2)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end
  end

  describe '#index' do
    it 'correctly returns themes' do
      ColorScheme.destroy_all
      Theme.destroy_all

      theme = Theme.new(name: 'my name', user_id: -1)
      theme.set_field(target: :common, name: :scss, value: '.body{color: black;}')
      theme.set_field(target: :desktop, name: :after_header, value: '<b>test</b>')

      theme.remote_theme = RemoteTheme.new(
        remote_url: 'awesome.git',
        remote_version: '7',
        local_version: '8',
        remote_updated_at: Time.zone.now
      )

      theme.save!

      # this will get serialized as well
      ColorScheme.create_from_base(name: "test", colors: [])

      get "/admin/themes.json"

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)

      expect(json["extras"]["color_schemes"].length).to eq(2)
      theme_json = json["themes"].find { |t| t["id"] == theme.id }
      expect(theme_json["theme_fields"].length).to eq(2)
      expect(theme_json["remote_theme"]["remote_version"]).to eq("7")
    end
  end

  describe '#create' do
    it 'creates a theme' do
      post "/admin/themes.json", params: {
        theme: {
          name: 'my test name',
          theme_fields: [name: 'scss', target: 'common', value: 'body{color: red;}']
        }
      }

      expect(response.status).to eq(201)

      json = ::JSON.parse(response.body)

      expect(json["theme"]["theme_fields"].length).to eq(1)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end
  end

  describe '#update' do
    let(:theme) { Theme.create(name: 'my name', user_id: -1) }

    it 'can change default theme' do
      SiteSetting.default_theme_key = nil

      put "/admin/themes/#{theme.id}.json", params: {
        id: theme.id, theme: { default: true }
      }

      expect(response.status).to eq(200)
      expect(SiteSetting.default_theme_key).to eq(theme.key)
    end

    it 'can unset default theme' do
      SiteSetting.default_theme_key = theme.key

      put "/admin/themes/#{theme.id}.json", params: {
        theme: { default: false }
      }

      expect(response.status).to eq(200)
      expect(SiteSetting.default_theme_key).to be_blank
    end

    it 'updates a theme' do
      theme.set_field(target: :common, name: :scss, value: '.body{color: black;}')
      theme.save

      child_theme = Theme.create(name: 'my name', user_id: -1)

      upload = Fabricate(:upload)

      put "/admin/themes/#{theme.id}.json", params: {
        theme: {
          child_theme_ids: [child_theme.id],
          name: 'my test name',
          theme_fields: [
            { name: 'scss', target: 'common', value: '' },
            { name: 'scss', target: 'desktop', value: 'body{color: blue;}' },
            { name: 'bob', target: 'common', value: '', type_id: 2, upload_id: upload.id },
          ]
        }
      }

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)

      fields = json["theme"]["theme_fields"].sort { |a, b| a["value"] <=> b["value"] }

      expect(fields[0]["value"]).to eq('')
      expect(fields[0]["upload_id"]).to eq(upload.id)
      expect(fields[1]["value"]).to eq('body{color: blue;}')
      expect(fields.length).to eq(2)
      expect(json["theme"]["child_themes"].length).to eq(1)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end
  end
end

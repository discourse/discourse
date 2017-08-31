require 'rails_helper'

describe Admin::ThemesController do

  it "is a subclass of AdminController" do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.upload_asset' do
      render_views

      let(:upload) do
        Rack::Test::UploadedFile.new(file_from_fixtures("fake.woff2", "woff2"))
      end

      it 'can create a theme upload' do
        post :upload_asset, params: { file: upload }, format: :json
        expect(response.status).to eq(201)

        upload = Upload.find_by(original_filename: "fake.woff2")

        expect(upload.id).not_to be_nil
        expect(JSON.parse(response.body)["upload_id"]).to eq(upload.id)
      end
    end

    context '.import' do
      let(:theme_file) do
        Rack::Test::UploadedFile.new(file_from_fixtures("sam-s-simple-theme.dcstyle.json", "json"))
      end

      it 'imports a theme' do
        post :import, params: { theme: theme_file }, format: :json
        expect(response).to be_success

        json = ::JSON.parse(response.body)

        expect(json["theme"]["name"]).to eq("Sam's Simple Theme")
        expect(json["theme"]["theme_fields"].length).to eq(2)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end
    end

    context ' .index' do
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

        get :index, format: :json

        expect(response).to be_success

        json = ::JSON.parse(response.body)

        expect(json["extras"]["color_schemes"].length).to eq(2)
        theme_json = json["themes"].find { |t| t["id"] == theme.id }
        expect(theme_json["theme_fields"].length).to eq(2)
        expect(theme_json["remote_theme"]["remote_version"]).to eq("7")
      end
    end

    context ' .create' do
      it 'creates a theme' do
        post :create, params: {
          theme: {
            name: 'my test name',
            theme_fields: [name: 'scss', target: 'common', value: 'body{color: red;}']
          }
        }, format: :json

        expect(response).to be_success

        json = ::JSON.parse(response.body)

        expect(json["theme"]["theme_fields"].length).to eq(1)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end
    end

    context ' .update' do
      it 'can change default theme' do
        theme = Theme.create(name: 'my name', user_id: -1)

        put :update, params: {
          id: theme.id, theme: { default: true }
        }, format: :json

        expect(SiteSetting.default_theme_key).to eq(theme.key)
      end

      it 'can unset default theme' do
        theme = Theme.create(name: 'my name', user_id: -1)
        SiteSetting.default_theme_key = theme.key

        put :update, params: {
          id: theme.id, theme: { default: false }
        }, format: :json

        expect(SiteSetting.default_theme_key).to be_blank
      end

      it 'updates a theme' do
        theme = Theme.new(name: 'my name', user_id: -1)
        theme.set_field(target: :common, name: :scss, value: '.body{color: black;}')
        theme.save

        child_theme = Theme.create(name: 'my name', user_id: -1)

        upload = Fabricate(:upload)

        put :update, params: {
          id: theme.id,
          theme: {
            child_theme_ids: [child_theme.id],
            name: 'my test name',
            theme_fields: [
              { name: 'scss', target: 'common', value: '' },
              { name: 'scss', target: 'desktop', value: 'body{color: blue;}' },
              { name: 'bob', target: 'common', value: '', type_id: 2, upload_id: upload.id },
            ]
          }
        }, format: :json

        expect(response).to be_success

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

end

require 'rails_helper'

describe Admin::ThemesController do

  it "is a subclass of AdminController" do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context ' .index' do
      it 'returns success' do
        theme = Theme.new(name: 'my name', user_id: -1)
        theme.set_field(:common, :scss, '.body{color: black;}')
        theme.set_field(:desktop, :after_header, '<b>test</b>')

        theme.remote_theme = RemoteTheme.new(
          remote_url: 'awesome.git',
          remote_version: '7',
          local_version: '8',
          remote_updated_at: Time.zone.now
        )

        theme.save!

        # this will get serialized as well
        ColorScheme.create_from_base(name: "test", colors: [])

        xhr :get, :index

        expect(response).to be_success

        json = ::JSON.parse(response.body)

        expect(json["extras"]["color_schemes"].length).to eq(2)
        theme_json = json["themes"].find{|t| t["id"] == theme.id}
        expect(theme_json["theme_fields"].length).to eq(2)
        expect(theme_json["remote_theme"]["remote_version"]).to eq("7")
      end
    end

    context ' .create' do
      it 'creates a theme' do
        xhr :post, :create, theme: {name: 'my test name', theme_fields: [name: 'scss', target: 'common', value: 'body{color: red;}']}
        expect(response).to be_success

        json = ::JSON.parse(response.body)

        expect(json["theme"]["theme_fields"].length).to eq(1)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end
    end

    context ' .update' do
      it 'can change default theme' do
        theme = Theme.create(name: 'my name', user_id: -1)
        xhr :put, :update, id: theme.id, theme: { default: true }
        expect(SiteSetting.default_theme_key).to eq(theme.key)
      end

      it 'can unset default theme' do
        theme = Theme.create(name: 'my name', user_id: -1)
        SiteSetting.default_theme_key = theme.key
        xhr :put, :update, id: theme.id, theme: { default: false}
        expect(SiteSetting.default_theme_key).to be_blank
      end

      it 'updates a theme' do

        theme = Theme.new(name: 'my name', user_id: -1)
        theme.set_field(:common, :scss, '.body{color: black;}')
        theme.save

        child_theme = Theme.create(name: 'my name', user_id: -1)

        xhr :put, :update, id: theme.id,
            theme: {
          child_theme_ids: [child_theme.id],
          name: 'my test name',
          theme_fields: [name: 'scss', target: 'common', value: 'body{color: red;}']
        }
        expect(response).to be_success

        json = ::JSON.parse(response.body)

        fields = json["theme"]["theme_fields"]

        expect(fields.length).to eq(1)
        expect(fields.first["value"]).to eq('body{color: red;}')

        expect(json["theme"]["child_themes"].length).to eq(1)

        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end
    end
  end

end

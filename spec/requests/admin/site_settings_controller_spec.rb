require 'rails_helper'

describe Admin::SiteSettingsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteSettingsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    let(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    describe '#index' do
      it 'returns valid info' do
        get "/admin/site_settings.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["site_settings"].length).to be > 100

        locale = json["site_settings"].select do |s|
          s["setting"] == "default_locale"
        end

        expect(locale.length).to eq(1)
      end
    end

    describe '#update' do
      before do
        SiteSetting.setting(:test_setting, "default")
        SiteSetting.setting(:test_upload, "", type: :upload)
        SiteSetting.refresh!
      end

      it 'sets the value when the param is present' do
        put "/admin/site_settings/test_setting.json", params: {
          test_setting: 'hello'
        }
        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq('hello')
      end

      it 'allows value to be a blank string' do
        put "/admin/site_settings/test_setting.json", params: {
          test_setting: ''
        }
        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq('')
      end

      it 'allows upload site settings to be updated' do
        upload = Fabricate(:upload)

        put "/admin/site_settings/test_upload.json", params: {
          test_upload: upload.url
        }

        expect(response.status).to eq(200)
        expect(SiteSetting.test_upload).to eq(upload)

        user_history = UserHistory.last

        expect(user_history.action).to eq(
          UserHistory.actions[:change_site_setting]
        )

        expect(user_history.previous_value).to eq(nil)
        expect(user_history.new_value).to eq(upload.url)

        put "/admin/site_settings/test_upload.json", params: {
          test_upload: nil
        }

        expect(response.status).to eq(200)
        expect(SiteSetting.test_upload).to eq(nil)
      end

      it 'logs the change' do
        SiteSetting.test_setting = 'previous'

        expect do
          put "/admin/site_settings/test_setting.json", params: {
            test_setting: 'hello'
          }
        end.to change { UserHistory.where(action: UserHistory.actions[:change_site_setting]).count }.by(1)

        expect(response.status).to eq(200)
        expect(SiteSetting.test_setting).to eq('hello')
      end

      it 'does not allow changing of hidden settings' do
        SiteSetting.setting(:hidden_setting, "hidden", hidden: true)
        SiteSetting.refresh!

        put "/admin/site_settings/hidden_setting.json", params: {
          hidden_setting: 'not allowed'
        }

        expect(SiteSetting.hidden_setting).to eq("hidden")
        expect(response.status).to eq(422)
      end

      it 'fails when a setting does not exist' do
        put "/admin/site_settings/provider.json", params: { provider: 'gotcha' }
        expect(response.status).to eq(422)
      end
    end
  end
end

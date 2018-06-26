require 'rails_helper'

RSpec.describe Admin::SiteTextsController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextsController < Admin::AdminController).to eq(true)
  end

  context "when not logged in as an admin" do
    it "raises an error if you aren't logged in" do
      put '/admin/customize/site_texts/some_key.json', params: {
        site_text: { value: 'foo' }
      }

      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)

      put "/admin/customize/site_texts/some_key.json", params: {
        site_text: { value: 'foo' }
      }

      expect(response.status).to eq(404)
    end
  end

  context "when logged in as amin" do
    before do
      sign_in(admin)
    end

    describe '#index' do
      it 'returns json' do
        get "/admin/customize/site_texts.json", params: {  q: 'title' }
        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    describe '#show' do
      it 'returns a site text for a key that exists' do
        get "/admin/customize/site_texts/js.topic.list.json"
        expect(response.status).to eq(200)

        json = ::JSON.parse(response.body)

        site_text = json['site_text']

        expect(site_text['id']).to eq('js.topic.list')
        expect(site_text['value']).to eq(I18n.t("js.topic.list"))
      end

      it 'returns not found for missing keys' do
        get "/admin/customize/site_texts/made_up_no_key_exists.json"
        expect(response.status).to eq(404)
      end
    end

    describe '#update & #revert' do
      it "returns 'not found' when an unknown key is used" do
        put '/admin/customize/site_texts/some_key.json', params: {
          site_text: { value: 'foo' }
        }

        expect(response.status).to eq(404)

        json = JSON.parse(response.body)
        expect(json['error_type']).to eq('not_found')
      end

      it "works as expectd with correct keys" do
        put '/admin/customize/site_texts/login_required.welcome_message.json', params: {
          site_text: { value: 'foo' }
        }

        expect(response.status).to eq(200)

        json = ::JSON.parse(response.body)
        site_text = json['site_text']

        expect(site_text['id']).to eq('login_required.welcome_message')
        expect(site_text['value']).to eq('foo')
      end

      it "does not update restricted keys" do
        put '/admin/customize/site_texts/user_notifications.confirm_old_email.title.json', params: {
          site_text: { value: 'foo' }
        }

        expect(response.status).to eq(404)

        json = ::JSON.parse(response.body)
        expect(json['error_type']).to eq('not_found')
      end

      it "returns the right error message" do
        I18n.backend.store_translations(:en, some_key: '%{first} %{second}')

        put "/admin/customize/site_texts/some_key.json", params: {
          site_text: { value: 'hello %{key} %{omg}' }
        }

        expect(response.status).to eq(422)

        body = JSON.parse(response.body)

        expect(body['message']).to eq(I18n.t(
          'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
          keys: 'key, omg'
        ))
      end

      it 'logs the change' do
        original_title = I18n.t(:title)

        put "/admin/customize/site_texts/title.json", params: {
          site_text: { value: 'yay' }
        }
        expect(response.status).to eq(200)

        log = UserHistory.last

        expect(log.previous_value).to eq(original_title)
        expect(log.new_value).to eq('yay')
        expect(log.action).to eq(UserHistory.actions[:change_site_text])

        delete "/admin/customize/site_texts/title.json"
        expect(response.status).to eq(200)

        log = UserHistory.last

        expect(log.previous_value).to eq('yay')
        expect(log.new_value).to eq(original_title)
        expect(log.action).to eq(UserHistory.actions[:change_site_text])
      end

      it 'updates and reverts the key' do
        orig_title = I18n.t(:title)

        put "/admin/customize/site_texts/title.json", params: { site_text: { value: 'hello' } }
        expect(response.status).to eq(200)

        json = ::JSON.parse(response.body)

        site_text = json['site_text']

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq('hello')

        # Revert
        delete "/admin/customize/site_texts/title.json"
        expect(response.status).to eq(200)

        json = ::JSON.parse(response.body)

        site_text = json['site_text']

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(orig_title)
      end

      it 'returns site texts for the correct locale' do
        SiteSetting.default_locale = :ru

        ru_title = 'title ru'
        ru_mf_text = 'ru {NUM_RESULTS, plural, one {1 result} other {many} }'

        put "/admin/customize/site_texts/title.json", params: { site_text: { value: ru_title } }
        expect(response.status).to eq(200)
        put "/admin/customize/site_texts/js.topic.read_more_MF.json", params: { site_text: { value: ru_mf_text } }
        expect(response.status).to eq(200)

        get "/admin/customize/site_texts/title.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to eq(ru_title)

        get "/admin/customize/site_texts/js.topic.read_more_MF.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to eq(ru_mf_text)

        SiteSetting.default_locale = :en

        get "/admin/customize/site_texts/title.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to_not eq(ru_title)

        get "/admin/customize/site_texts/js.topic.read_more_MF.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to_not eq(ru_mf_text)
      end
    end
  end
end

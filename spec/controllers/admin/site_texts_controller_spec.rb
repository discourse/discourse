require 'rails_helper'

describe Admin::SiteTextsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.index' do
      it 'returns json' do
        get :index, params: {  q: 'title' }, format: :json
        expect(response).to be_success
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    context '.show' do
      it 'returns a site text for a key that exists' do
        get :show, params: { id: 'title' }, format: :json
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(I18n.t(:title))
      end

      it 'returns not found for missing keys' do
        get :show, params: { id: 'made_up_no_key_exists' }, format: :json
        expect(response).not_to be_success
      end
    end

    context '#update and #revert' do
      after do
        TranslationOverride.delete_all
        I18n.reload!
      end

      describe 'failure' do
        before do
          I18n.backend.store_translations(:en, some_key: '%{first} %{second}')
        end

        it 'returns the right error message' do
          put :update, params: {
            id: 'some_key', site_text: { value: 'hello %{key} %{omg}' }
          }, format: :json

          expect(response.status).to eq(422)

          body = JSON.parse(response.body)

          expect(body['message']).to eq(I18n.t(
            'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
            keys: 'key, omg'
          ))
        end
      end

      it 'updates and reverts the key' do
        orig_title = I18n.t(:title)

        put :update, params: { id: 'title', site_text: { value: 'hello' } }, format: :json
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq('hello')

        # Revert
        put :revert, params: { id: 'title' }, format: :json
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(orig_title)
      end

      it 'returns not found for missing keys' do
        put :update, params: {
          id: 'made_up_no_key_exists', site_text: { value: 'hello' }
        }, format: :json

        expect(response).not_to be_success
      end

      it 'logs the change' do
        original_title = I18n.t(:title)

        put :update, params: {
          id: 'title', site_text: { value: 'yay' }
        }, format: :json

        log = UserHistory.last

        expect(log.previous_value).to eq(original_title)
        expect(log.new_value).to eq('yay')
        expect(log.action).to eq(UserHistory.actions[:change_site_text])

        put :revert, params: { id: 'title' }, format: :json

        log = UserHistory.last

        expect(log.previous_value).to eq('yay')
        expect(log.new_value).to eq(original_title)
        expect(log.action).to eq(UserHistory.actions[:change_site_text])
      end

      it 'returns site texts for the correct locale' do
        SiteSetting.default_locale = :ru

        ru_title = 'title ru'
        ru_mf_text = 'ru {NUM_RESULTS, plural, one {1 result} other {many} }'

        put :update, params: { id: 'title', site_text: { value: ru_title } }, format: :json
        put :update, params: { id: 'js.topic.read_more_MF', site_text: { value: ru_mf_text } }, format: :json

        get :show, params: { id: 'title' }, format: :json
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to eq(ru_title)

        get :show, params: { id: 'js.topic.read_more_MF' }, format: :json
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to eq(ru_mf_text)

        SiteSetting.default_locale = :en

        get :show, params: { id: 'title' }, format: :json
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to_not eq(ru_title)

        get :show, params: { id: 'js.topic.read_more_MF' }, format: :json
        json = ::JSON.parse(response.body)
        expect(json['site_text']['value']).to_not eq(ru_mf_text)
      end
    end
  end

end

require 'rails_helper'

RSpec.describe Admin::SiteTextsController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  context "#update" do
    it "raises an error if you aren't logged in" do
      put '/admin/customize/site_texts/some_key.json', params: {
        site_text: { value: 'foo' }
      }

      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)

      put '/admin/customize/site_texts/some_key', params: {
        site_text: { value: 'foo' }
      }

      expect(response.status).to eq(404)
    end

    context "when logged in as admin" do
      before do
        sign_in(admin)
      end

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
    end
  end
end

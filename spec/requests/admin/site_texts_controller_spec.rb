require 'rails_helper'

RSpec.describe Admin::SiteTextsController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }
  let(:headers) { { ACCEPT: 'application/json' } }

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  context "#update" do
    it "raises an error if you aren't logged in" do
      put '/admin/customize/site_texts/some_key', params: {
        site_text: { value: 'foo' }
      }, headers: headers
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)
      put '/admin/customize/site_texts/some_key', params: {
        site_text: { value: 'foo' }
      }, headers: headers
      expect(response.status).to eq(404)
    end

    context "when logged in as admin" do
      before do
        sign_in(admin)
      end

      it "returns 'not found' when an unknown key is used" do
        put '/admin/customize/site_texts/some_key', params: {
          site_text: { value: 'foo' }
        }, headers: headers

        expect(response).not_to be_success

        json = ::JSON.parse(response.body)
        expect(json['error_type']).to eq('not_found')
      end

      it "works as expectd with correct keys" do
        put '/admin/customize/site_texts/title', params: {
          site_text: { value: 'foo' }
        }, headers: headers

        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq('foo')
      end

      it "does not update restricted keys" do
        put '/admin/customize/site_texts/user_notifications.confirm_old_email.title', params: {
          site_text: { value: 'foo' }
        }, headers: headers

        expect(response).not_to be_success

        json = ::JSON.parse(response.body)
        expect(json['error_type']).to eq('not_found')
      end
    end
  end
end

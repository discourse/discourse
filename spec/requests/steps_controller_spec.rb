require 'rails_helper'

describe StepsController do
  before { SiteSetting.wizard_enabled = true }

  it 'needs you to be logged in' do
    put '/wizard/steps/made-up-id.json',
        params: { fields: { forum_title: 'updated title' } }
    expect(response.status).to eq(403)
  end

  it "raises an error if you aren't an admin" do
    sign_in(Fabricate(:moderator))

    put '/wizard/steps/made-up-id.json',
        params: { fields: { forum_title: 'updated title' } }

    expect(response).to be_forbidden
  end

  context 'as an admin' do
    before { sign_in(Fabricate(:admin)) }

    it 'raises an error if the wizard is disabled' do
      SiteSetting.wizard_enabled = false
      put '/wizard/steps/contact.json',
          params: { fields: { contact_email: 'eviltrout@example.com' } }
      expect(response).to be_forbidden
    end

    it 'updates properly if you are staff' do
      put '/wizard/steps/contact.json',
          params: { fields: { contact_email: 'eviltrout@example.com' } }

      expect(response.status).to eq(200)
      expect(SiteSetting.contact_email).to eq('eviltrout@example.com')
    end

    it 'returns errors if the field has them' do
      put '/wizard/steps/contact.json',
          params: { fields: { contact_email: 'not-an-email' } }

      expect(response.status).to eq(422)
    end
  end
end

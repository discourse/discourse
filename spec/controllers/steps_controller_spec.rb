require 'rails_helper'

describe StepsController do

  before do
    SiteSetting.wizard_enabled = true
  end

  it 'needs you to be logged in' do
    expect do
      put :update, params: {
        id: 'made-up-id', fields: { forum_title: "updated title" }
      }, format: :json
    end.to raise_error(Discourse::NotLoggedIn)
  end

  it "raises an error if you aren't an admin" do
    log_in(:moderator)

    put :update, params: {
      id: 'made-up-id', fields: { forum_title: "updated title" }
    }, format: :json

    expect(response).to be_forbidden
  end

  context "as an admin" do
    before do
      log_in(:admin)
    end

    it "raises an error if the wizard is disabled" do
      SiteSetting.wizard_enabled = false
      put :update, params: {
        id: 'contact', fields: { contact_email: "eviltrout@example.com" }
      }, format: :json
      expect(response).to be_forbidden
    end

    it "updates properly if you are staff" do
      put :update, params: {
        id: 'contact', fields: { contact_email: "eviltrout@example.com" }
      }, format: :json

      expect(response).to be_success
      expect(SiteSetting.contact_email).to eq("eviltrout@example.com")
    end

    it "returns errors if the field has them" do
      put :update, params: {
        id: 'contact', fields: { contact_email: "not-an-email" }
      }, format: :json

      expect(response).to_not be_success
    end
  end

end

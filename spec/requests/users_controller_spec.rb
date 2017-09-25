require 'rails_helper'

RSpec.describe UsersController do
  let(:user) { Fabricate(:user) }

  describe '#show' do

    it "should be able to view a user" do
      get "/u/#{user.username}"

      expect(response).to be_success
      expect(response.body).to include(user.username)
    end

    describe 'when username contains a period' do
      before do
        user.update!(username: 'test.test')
      end

      it "should be able to view a user" do
        get "/u/#{user.username}"

        expect(response).to be_success
        expect(response.body).to include(user.username)
      end
    end
  end

  describe "updating a user" do
    before do
      sign_in(user)
    end

    it "should be able to update a user" do
      put "/u/#{user.username}.json", params: { name: 'test.test' }

      expect(response).to be_success
      expect(user.reload.name).to eq('test.test')
    end

    describe 'when username contains a period' do
      before do
        user.update!(username: 'test.test')
      end

      it "should be able to update a user" do
        put "/u/#{user.username}.json", params: { name: 'testing123' }

        expect(response).to be_success
        expect(user.reload.name).to eq('testing123')
      end
    end
  end

  describe "#account_created" do
    it "returns a message when no session is present" do
      get "/u/account-created"

      expect(response).to be_success

      body = response.body

      expect(body).to match(I18n.t('activation.missing_session'))
    end

    it "redirects when the user is logged in" do
      sign_in(Fabricate(:user))
      get "/u/account-created"

      expect(response).to redirect_to("/")
    end

    context "when the user account is created" do
      include ApplicationHelper

      it "returns the message when set in the session" do
        user = create_user
        get "/u/account-created"

        expect(response).to be_success

        expect(response.body).to include(
          "{\"message\":\"#{I18n.t("login.activate_email", email: user.email).gsub!("</", "<\\/")}\",\"show_controls\":true,\"username\":\"#{user.username}\",\"email\":\"#{user.email}\"}"
        )
      end
    end
  end
end

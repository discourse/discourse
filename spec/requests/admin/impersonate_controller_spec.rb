# frozen_string_literal: true

require 'rails_helper'

describe Admin::ImpersonateController do

  it "is a subclass of AdminController" do
    expect(Admin::ImpersonateController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }
    fab!(:another_admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    describe '#index' do
      it 'returns success' do
        get "/admin/impersonate.json"
        expect(response.status).to eq(200)
      end
    end

    describe '#create' do
      it 'requires a username_or_email parameter' do
        post "/admin/impersonate.json"
        expect(response.status).to eq(400)
        expect(session[:current_user_id]).to eq(admin.id)
      end

      it 'returns 404 when that user does not exist' do
        post "/admin/impersonate.json", params: { username_or_email: 'hedonismbot' }
        expect(response.status).to eq(404)
        expect(session[:current_user_id]).to eq(admin.id)
      end

      it "raises an invalid access error if the user can't be impersonated" do
        post "/admin/impersonate.json", params: { username_or_email: another_admin.email }
        expect(response.status).to eq(403)
        expect(session[:current_user_id]).to eq(admin.id)
      end

      context 'success' do
        it "succeeds and logs the impersonation" do
          expect do
            post "/admin/impersonate.json", params: { username_or_email: user.username }
          end.to change { UserHistory.where(action: UserHistory.actions[:impersonate]).count }.by(1)

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end

        it "also works with an email address" do
          post "/admin/impersonate.json", params: { username_or_email: user.email }
          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end
      end
    end
  end
end

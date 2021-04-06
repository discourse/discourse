# frozen_string_literal: true

require 'rails_helper'
require 'rotp'

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

      context 'when user has TOTP-only 2FA enabled' do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: admin) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: admin) }

        describe 'when second factor token is missing' do
          it 'should return the right response' do
            post "/admin/impersonate.json", params: {
              username_or_email: user.username
            }

            expect(response.status).to eq(200)
            expect(response.parsed_body['error']).to eq(I18n.t(
              'login.invalid_second_factor_method'
            ))
          end
        end

        describe 'when second factor token is invalid' do
          context 'when using totp method' do
            it 'should return the right response' do
              post "/admin/impersonate.json", params: {
                username_or_email: user.username,
                second_factor_token: '00000000',
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response.status).to eq(200)
              expect(response.parsed_body['error']).to eq(I18n.t(
                'login.invalid_second_factor_code'
              ))
            end
          end

          context 'when using backup code method' do
            it 'should return the right response' do
              post "/admin/impersonate.json", params: {
                username_or_email: user.username,
                second_factor_token: '00000000',
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response.status).to eq(200)
              expect(response.parsed_body['error']).to eq(I18n.t(
                'login.invalid_second_factor_code'
              ))
            end
          end
        end

        describe 'when second factor token is valid' do
          context 'when using totp method' do
            it 'should impersonate the user' do
              post "/admin/impersonate.json", params: {
                username_or_email: user.username,
                second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                second_factor_method: UserSecondFactor.methods[:totp]
              }
              expect(response.status).to eq(200)
              expect(session[:current_user_id]).to eq(user.id)
            end
          end
          context 'when using backup code method' do
            it 'should impersonate the user' do
              post "/admin/impersonate.json", params: {
                username_or_email: user.username,
                second_factor_token: 'iAmValidBackupCode',
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }
              expect(response.status).to eq(200)
              expect(session[:current_user_id]).to eq(user.id)
            end
          end
        end
      end
    end
  end
end

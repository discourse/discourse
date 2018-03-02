require 'rails_helper'

RSpec.describe SessionController do
  let(:email_token) { Fabricate(:email_token) }
  let(:user) { email_token.user }

  describe '#email_login' do
    before do
      SiteSetting.enable_local_logins_via_email = true
    end

    context 'missing token' do
      it 'returns the right response' do
        get "/session/email-login"
        expect(response.status).to eq(404)
      end
    end

    context 'invalid token' do
      it 'returns the right response' do
        get "/session/email-login/adasdad"

        expect(response).to be_success

        expect(CGI.unescapeHTML(response.body)).to match(
          I18n.t('email_login.invalid_token')
        )
      end

      context 'when token has expired' do
        it 'should return the right response' do
          email_token.update!(created_at: 999.years.ago)

          get "/session/email-login/#{email_token.token}"

          expect(response).to be_success

          expect(CGI.unescapeHTML(response.body)).to match(
            I18n.t('email_login.invalid_token')
          )
        end
      end
    end

    context 'valid token' do
      it 'returns success' do
        get "/session/email-login/#{email_token.token}"

        expect(response).to redirect_to("/")
      end

      it 'fails when local logins via email is disabled' do
        SiteSetting.enable_local_logins_via_email = false

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(404)
      end

      it 'fails when local logins is disabled' do
        SiteSetting.enable_local_logins = false

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(500)
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.must_approve_users = true

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to include(
          I18n.t("login.not_approved")
        )
      end

      context "when admin IP address is not valid" do
        before do
          Fabricate(:screened_ip_address,
            ip_address: "111.111.11.11",
            action_type: ScreenedIpAddress.actions[:allow_admin]
          )

          SiteSetting.use_admin_ip_whitelist = true
          user.update!(admin: true)
        end

        it 'returns the right response' do
          get "/session/email-login/#{email_token.token}"

          expect(response.status).to eq(200)

          expect(CGI.unescapeHTML(response.body)).to include(
            I18n.t("login.admin_not_allowed_from_ip_address", username: user.username)
          )
        end
      end

      context "when IP address is blocked" do
        let(:permitted_ip_address) { '111.234.23.11' }

        before do
          Fabricate(:screened_ip_address,
            ip_address: permitted_ip_address,
            action_type: ScreenedIpAddress.actions[:block]
          )
        end

        it 'returns the right response' do
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(permitted_ip_address)

          get "/session/email-login/#{email_token.token}"

          expect(response.status).to eq(200)

          expect(CGI.unescapeHTML(response.body)).to include(
            I18n.t("login.not_allowed_from_ip_address", username: user.username)
          )
        end
      end

      it "fails when user is suspended" do
        user.update!(
          suspended_till: 2.days.from_now,
          suspended_at: Time.zone.now
        )

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to include(I18n.t("login.suspended",
          date: I18n.l(user.suspended_till, format: :date_only)
        ))
      end

      context 'user has 2-factor logins' do
        let!(:user_second_factor) { Fabricate(:user_second_factor, user: user) }

        describe 'requires second factor' do
          it 'should return a second factor prompt' do
            get "/session/email-login/#{email_token.token}"

            expect(response.status).to eq(200)

            response_body = CGI.unescapeHTML(response.body)

            expect(response_body).to include(I18n.t(
              "login.second_factor_title"
            ))

            expect(response_body).to_not include(I18n.t(
              "login.invalid_second_factor_code"
            ))
          end
        end

        describe 'errors on incorrect 2-factor' do
          it 'does not log in with incorrect two factor' do
            post "/session/email-login/#{email_token.token}", params: { second_factor_token: "0000" }

            expect(response.status).to eq(200)

            expect(CGI.unescapeHTML(response.body)).to include(I18n.t(
              "login.invalid_second_factor_code"
            ))
          end
        end

        describe 'allows successful 2-factor' do
          it 'logs in correctly' do
            post "/session/email-login/#{email_token.token}", params: {
              second_factor_token: ROTP::TOTP.new(user_second_factor.data).now
            }

            expect(response).to redirect_to("/")
          end
        end
      end
    end
  end
end

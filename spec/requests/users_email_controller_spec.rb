# frozen_string_literal: true

require 'rails_helper'
require 'rotp'

describe UsersEmailController do

  fab!(:user) { Fabricate(:user) }
  fab!(:moderator) { Fabricate(:moderator) }

  describe "#confirm-new-email" do
    it 'redirects to login for signed out accounts' do
      get "/u/confirm-new-email/asdfasdf"

      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq("http://test.localhost/login")
    end

    it 'errors out for invalid tokens' do
      sign_in(user)

      get "/u/confirm-new-email/asdfasdf"

      expect(response.status).to eq(200)
      expect(response.body).to include(I18n.t('change_email.already_done'))
    end

    it 'does not change email if accounts mismatch' do
      updater = EmailUpdater.new(user.guardian, user)
      updater.change_to('new.n.cool@example.com')

      old_email = user.email

      sign_in(moderator)

      put "/u/confirm-new-email", params: {
        token: "#{user.email_tokens.last.token}"
      }

      user.reload
      expect(user.email).to eq(old_email)
    end

    context "with a valid user" do
      let(:updater) { EmailUpdater.new(user.guardian, user) }

      before do
        sign_in(user)
        updater.change_to('new.n.cool@example.com')
      end

      it 'confirms with a correct token' do
        user.user_stat.update_columns(bounce_score: 42, reset_bounce_score_after: 1.week.from_now)

        put "/u/confirm-new-email", params: {
          token: "#{user.email_tokens.last.token}"
        }

        expect(response.status).to eq(302)
        expect(response.redirect_url).to include("done")

        user.reload

        expect(user.user_stat.bounce_score).to eq(0)
        expect(user.user_stat.reset_bounce_score_after).to eq(nil)
        expect(user.email).to eq("new.n.cool@example.com")
      end

      context 'second factor required' do
        fab!(:second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        fab!(:backup_code) { Fabricate(:user_second_factor_backup, user: user) }

        it 'requires a second factor token' do
          get "/u/confirm-new-email/#{user.email_tokens.last.token}"

          expect(response.status).to eq(200)

          response_body = response.body

          expect(response_body).to include(I18n.t("login.second_factor_title"))
          expect(response_body).not_to include(I18n.t("login.invalid_second_factor_code"))
        end

        it 'requires a backup token' do
          get "/u/confirm-new-email/#{user.email_tokens.last.token}?show_backup=true"

          expect(response.status).to eq(200)

          response_body = response.body

          expect(response_body).to include(I18n.t("login.second_factor_backup_title"))
        end

        it 'adds an error on a second factor attempt' do
          put "/u/confirm-new-email", params: {
            token: user.email_tokens.last.token,
            second_factor_token: "000000",
            second_factor_method: UserSecondFactor.methods[:totp]
          }

          expect(response.status).to eq(302)
          expect(flash[:invalid_second_factor]).to eq(true)
        end

        it 'confirms with a correct second token' do
          put "/u/confirm-new-email", params: {
            second_factor_token: ROTP::TOTP.new(second_factor.data).now,
            second_factor_method: UserSecondFactor.methods[:totp],
            token: user.email_tokens.last.token
          }

          expect(response.status).to eq(302)

          user.reload
          expect(user.email).to eq("new.n.cool@example.com")
        end
      end

      context "security key required" do
        fab!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key]
          )
        end

        before do
          simulate_localhost_webauthn_challenge
        end

        it 'requires a security key' do
          get "/u/confirm-new-email/#{user.email_tokens.last.token}"

          expect(response.status).to eq(200)

          response_body = response.body

          expect(response_body).to include(I18n.t("login.security_key_authenticate"))
          expect(response_body).to include(I18n.t("login.security_key_description"))
        end

        context "if the user has a TOTP enabled and wants to use that instead" do
          before do
            Fabricate(:user_second_factor_totp, user: user)
          end

          it 'allows entering the totp code instead' do
            get "/u/confirm-new-email/#{user.email_tokens.last.token}?show_totp=true"

            expect(response.status).to eq(200)

            response_body = response.body

            expect(response_body).to include(I18n.t("login.second_factor_title"))
            expect(response_body).not_to include(I18n.t("login.security_key_authenticate"))
          end
        end

        it 'adds an error on a security key attempt' do
          get "/u/confirm-new-email/#{user.email_tokens.last.token}"
          put "/u/confirm-new-email", params: {
            token: user.email_tokens.last.token,
            second_factor_token: "{}",
            second_factor_method: UserSecondFactor.methods[:security_key]
          }

          expect(response.status).to eq(302)
          expect(flash[:invalid_second_factor]).to eq(true)
        end

        it 'confirms with a correct security key token' do
          get "/u/confirm-new-email/#{user.email_tokens.last.token}"
          put "/u/confirm-new-email", params: {
            second_factor_token: valid_security_key_auth_post_data.to_json,
            second_factor_method: UserSecondFactor.methods[:security_key],
            token: user.email_tokens.last.token
          }

          expect(response.status).to eq(302)

          user.reload
          expect(user.email).to eq("new.n.cool@example.com")
        end

        context "if the security key data JSON is garbled" do
          it "raises an invalid parameters error" do
            get "/u/confirm-new-email/#{user.email_tokens.last.token}"
            put "/u/confirm-new-email", params: {
              second_factor_token: "{someweird: 8notjson}",
              second_factor_method: UserSecondFactor.methods[:security_key],
              token: user.email_tokens.last.token
            }

            expect(response.status).to eq(400)
          end
        end
      end
    end
  end

  describe '#confirm-old-email' do

    it 'redirects to login for signed out accounts' do
      get "/u/confirm-old-email/asdfasdf"

      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq("http://test.localhost/login")
    end

    it 'errors out for invalid tokens' do
      sign_in(user)

      get "/u/confirm-old-email/asdfasdf"

      expect(response.status).to eq(200)
      expect(response.body).to include(I18n.t('change_email.already_done'))
    end

    it 'bans change when accounts do not match' do

      sign_in(user)
      updater = EmailUpdater.new(moderator.guardian, moderator)
      updater.change_to('new.n.cool@example.com')

      get "/u/confirm-old-email/#{moderator.email_tokens.last.token}"

      expect(response.status).to eq(200)
      expect(body).to include("alert-error")
    end

    context 'valid old address token' do

      it 'confirms with a correct token' do
        # NOTE: only moderators need to confirm both old and new
        sign_in(moderator)
        updater = EmailUpdater.new(moderator.guardian, moderator)
        updater.change_to('new.n.cool@example.com')

        get "/u/confirm-old-email/#{moderator.email_tokens.last.token}"

        expect(response.status).to eq(200)

        body = CGI.unescapeHTML(response.body)

        expect(body)
          .to include(I18n.t('change_email.authorizing_old.title'))

        expect(body)
          .to include(I18n.t('change_email.authorizing_old.description'))

        put "/u/confirm-old-email", params: {
          token: moderator.email_tokens.last.token
        }

        expect(response.status).to eq(302)
        expect(response.redirect_url).to include("done=true")

      end
    end
  end

  describe '#update' do
    let(:new_email) { 'bubblegum@adventuretime.ooo' }

    it "requires you to be logged in" do
      put "/u/#{user.username}/preferences/email.json", params: { email: new_email }
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      before do
        sign_in(user)
      end

      it 'raises an error without an email parameter' do
        put "/u/#{user.username}/preferences/email.json"
        expect(response.status).to eq(400)
      end

      it 'raises an error without an invalid email' do
        put "/u/#{user.username}/preferences/email.json", params: { email: "sam@not-email.com'" }
        expect(response.status).to eq(422)
        expect(response.body).to include("email is invalid")
      end

      it "raises an error if you can't edit the user's email" do
        Guardian.any_instance.expects(:can_edit_email?).with(user).returns(false)

        put "/u/#{user.username}/preferences/email.json", params: { email: new_email }

        expect(response).to be_forbidden
      end

      context 'when the new email address is taken' do
        fab!(:other_user) { Fabricate(:coding_horror) }

        context 'hide_email_address_taken is disabled' do
          before do
            SiteSetting.hide_email_address_taken = false
          end

          it 'raises an error' do
            put "/u/#{user.username}/preferences/email.json", params: {
              email: other_user.email
            }

            expect(response).to_not be_successful
          end

          it 'raises an error if there is whitespace too' do
            put "/u/#{user.username}/preferences/email.json", params: {
              email: "#{other_user.email} "
            }

            expect(response).to_not be_successful
          end
        end

        context 'hide_email_address_taken is enabled' do
          before do
            SiteSetting.hide_email_address_taken = true
          end

          it 'responds with success' do
            put "/u/#{user.username}/preferences/email.json", params: {
              email: other_user.email
            }

            expect(response.status).to eq(200)
          end
        end
      end

      context 'when new email is different case of existing email' do
        fab!(:other_user) { Fabricate(:user, email: 'case.insensitive@gmail.com') }

        it 'raises an error' do
          put "/u/#{user.username}/preferences/email.json", params: {
            email: other_user.email.upcase
          }

          expect(response).to_not be_successful
        end
      end

      it 'raises an error when new email domain is present in email_domains_blacklist site setting' do
        SiteSetting.email_domains_blacklist = "mailinator.com"

        put "/u/#{user.username}/preferences/email.json", params: {
          email: "not_good@mailinator.com"
        }

        expect(response).to_not be_successful
      end

      it 'raises an error when new email domain is not present in email_domains_whitelist site setting' do
        SiteSetting.email_domains_whitelist = "discourse.org"

        put "/u/#{user.username}/preferences/email.json", params: {
          email: new_email
        }

        expect(response).to_not be_successful
      end

      context 'success' do
        it 'has an email token' do
          expect do
            put "/u/#{user.username}/preferences/email.json", params: {
              email: new_email
            }
          end.to change(EmailChangeRequest, :count)
        end
      end
    end

  end

end

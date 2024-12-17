# frozen_string_literal: true

require "rotp"

RSpec.describe UsersEmailController do
  fab!(:user)
  let!(:email_token) { Fabricate(:email_token, user: user) }
  fab!(:moderator)

  describe "#confirm-new-email" do
    it "does not redirect to login for signed out accounts, this route works fine as anon user" do
      get "/u/confirm-new-email/invalidtoken"

      expect(response.status).to eq(200)
    end

    it "does not redirect to login for signed out accounts on login_required sites, this route works fine as anon user" do
      SiteSetting.login_required = true
      get "/u/confirm-new-email/invalidtoken"

      expect(response.status).to eq(200)
    end

    it "errors out for invalid tokens" do
      sign_in(user)

      get "/u/confirm-new-email/invalidtoken.json"

      expect(response.status).to eq(404)
    end

    it "does not change email if accounts mismatch for a signed in user" do
      updater = EmailUpdater.new(guardian: user.guardian, user: user)
      updater.change_to("bubblegum@adventuretime.ooo")

      old_email = user.email

      sign_in(moderator)

      put "/u/confirm-new-email/#{email_token.token}.json"
      expect(response.status).to eq(404)
      expect(user.reload.email).to eq(old_email)
    end

    context "with a valid user" do
      let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

      before do
        sign_in(user)
        updater.change_to("bubblegum@adventuretime.ooo")
      end

      it "confirms with a correct token" do
        user.user_stat.update_columns(bounce_score: 42, reset_bounce_score_after: 1.week.from_now)

        put "/u/confirm-new-email/#{updater.change_req.new_email_token.token}.json"

        expect(response.status).to eq(200)
        user.reload
        expect(user.user_stat.bounce_score).to eq(0)
        expect(user.user_stat.reset_bounce_score_after).to eq(nil)
        expect(user.email).to eq("bubblegum@adventuretime.ooo")
      end
    end

    it "destroys email tokens associated with the old email after the new email is confirmed" do
      SiteSetting.enable_secondary_emails = true

      email_token =
        user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:password_reset])

      updater = EmailUpdater.new(guardian: user.guardian, user: user)
      updater.change_to("bubblegum@adventuretime.ooo")

      sign_in(user)
      put "/u/confirm-new-email/#{updater.change_req.new_email_token.token}.json"
      expect(response.status).to eq(200)

      new_password = SecureRandom.hex
      put "/u/password-reset/#{email_token.token}.json", params: { password: new_password }
      expect(response.parsed_body["success"]).to eq(false)
      expect(response.parsed_body["message"]).to eq(
        I18n.t("password_reset.no_token", base_url: Discourse.base_url),
      )
      expect(user.reload.confirm_password?(new_password)).to eq(false)
    end
  end

  describe "#confirm-old-email" do
    it "errors out for invalid tokens" do
      sign_in(user)

      get "/u/confirm-old-email/invalidtoken.json"

      expect(response.status).to eq(404)
    end

    it "bans change when accounts do not match" do
      sign_in(user)
      updater = EmailUpdater.new(guardian: moderator.guardian, user: moderator)
      email_change_request = updater.change_to("bubblegum@adventuretime.ooo")

      get "/u/confirm-old-email/#{email_change_request.old_email_token.token}.json"

      expect(response.status).to eq(403)
    end

    context "with valid old token" do
      it "confirms with a correct token" do
        sign_in(moderator)
        updater = EmailUpdater.new(guardian: moderator.guardian, user: moderator)
        email_change_request = updater.change_to("bubblegum@adventuretime.ooo")

        get "/u/confirm-old-email/#{email_change_request.old_email_token.token}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["old_email"]).to eq(moderator.email)
        expect(response.parsed_body["new_email"]).to eq("bubblegum@adventuretime.ooo")

        put "/u/confirm-old-email/#{email_change_request.old_email_token.token}.json"

        expect(response.status).to eq(200)
      end
    end
  end

  describe "#create" do
    it "has an email token" do
      sign_in(user)

      expect {
        post "/u/#{user.username}/preferences/email.json",
             params: {
               email: "bubblegum@adventuretime.ooo",
             }
      }.to change(EmailChangeRequest, :count)

      emailChangeRequest = EmailChangeRequest.last
      expect(emailChangeRequest.old_email).to eq(nil)
      expect(emailChangeRequest.new_email).to eq("bubblegum@adventuretime.ooo")
    end
  end

  describe "#update" do
    it "requires you to be logged in" do
      put "/u/#{user.username}/preferences/email.json",
          params: {
            email: "bubblegum@adventuretime.ooo",
          }
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "raises an error without an email parameter" do
        put "/u/#{user.username}/preferences/email.json"
        expect(response.status).to eq(400)
      end

      it "raises an error without an invalid email" do
        put "/u/#{user.username}/preferences/email.json", params: { email: "sam@not-email.com'" }
        expect(response.status).to eq(422)
        expect(response.body).to include("Email is invalid")
      end

      it "raises an error if you can't edit the user's email" do
        SiteSetting.email_editable = false

        put "/u/#{user.username}/preferences/email.json",
            params: {
              email: "bubblegum@adventuretime.ooo",
            }
        expect(response).to be_forbidden
      end

      context "when the new email address is taken" do
        fab!(:other_user) { Fabricate(:coding_horror) }

        context "when hide_email_address_taken is disabled" do
          before { SiteSetting.hide_email_address_taken = false }

          it "raises an error" do
            put "/u/#{user.username}/preferences/email.json", params: { email: other_user.email }
            expect(response).to_not be_successful
          end

          it "raises an error if there is whitespace too" do
            put "/u/#{user.username}/preferences/email.json",
                params: {
                  email: "#{other_user.email} ",
                }
            expect(response).to_not be_successful
          end
        end

        context "when hide_email_address_taken is enabled" do
          before { SiteSetting.hide_email_address_taken = true }

          it "responds with success" do
            put "/u/#{user.username}/preferences/email.json", params: { email: other_user.email }
            expect(response.status).to eq(200)
          end
        end
      end

      context "when new email is different case of existing email" do
        fab!(:other_user) { Fabricate(:user, email: "case.insensitive@gmail.com") }

        context "when hiding taken e-mails" do
          it "raises an error" do
            put "/u/#{user.username}/preferences/email.json",
                params: {
                  email: other_user.email.upcase,
                }
            expect(response).to be_successful
          end
        end

        context "when revealing taken e-mails" do
          before { SiteSetting.hide_email_address_taken = false }

          it "raises an error" do
            put "/u/#{user.username}/preferences/email.json",
                params: {
                  email: other_user.email.upcase,
                }
            expect(response).to_not be_successful
          end
        end
      end

      it "raises an error when new email domain is present in blocked_email_domains site setting" do
        SiteSetting.blocked_email_domains = "mailinator.com"

        put "/u/#{user.username}/preferences/email.json",
            params: {
              email: "not_good@mailinator.com",
            }
        expect(response).to_not be_successful
      end

      it "raises an error when new email domain is not present in allowed_email_domains site setting" do
        SiteSetting.allowed_email_domains = "discourse.org"

        put "/u/#{user.username}/preferences/email.json",
            params: {
              email: "bubblegum@adventuretime.ooo",
            }
        expect(response).to_not be_successful
      end

      context "with success" do
        it "has an email token" do
          expect do
            put "/u/#{user.username}/preferences/email.json",
                params: {
                  email: "bubblegum@adventuretime.ooo",
                }
          end.to change(EmailChangeRequest, :count)
        end
      end
    end
  end
end

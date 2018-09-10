require 'rails_helper'

describe UsersEmailController do

  describe '#confirm' do
    it 'errors out for invalid tokens' do
      get "/u/authorize-email/asdfasdf"

      expect(response.status).to eq(200)
      expect(response.body).to include(I18n.t('change_email.already_done'))
    end

    context 'valid old address token' do
      let(:user) { Fabricate(:moderator) }
      let(:updater) { EmailUpdater.new(user.guardian, user) }

      before do
        updater.change_to('new.n.cool@example.com')
      end

      it 'confirms with a correct token' do
        get "/u/authorize-email/#{user.email_tokens.last.token}"

        expect(response.status).to eq(200)

        body = CGI.unescapeHTML(response.body)

        expect(body)
          .to include(I18n.t('change_email.authorizing_old.title'))

        expect(body)
          .to include(I18n.t('change_email.authorizing_old.description'))
      end
    end

    context 'valid new address token' do
      let(:user) { Fabricate(:user) }
      let(:updater) { EmailUpdater.new(user.guardian, user) }

      before do
        updater.change_to('new.n.cool@example.com')
      end

      it 'confirms with a correct token' do
        user.user_stat.update_columns(bounce_score: 42, reset_bounce_score_after: 1.week.from_now)

        events = DiscourseEvent.track_events do
          get "/u/authorize-email/#{user.email_tokens.last.token}"
        end

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in, :user_first_logged_in
        )

        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t('change_email.confirmed'))

        user.reload

        expect(user.user_stat.bounce_score).to eq(0)
        expect(user.user_stat.reset_bounce_score_after).to eq(nil)
      end

      it 'automatically adds the user to a group when the email matches' do
        group = Fabricate(:group, automatic_membership_email_domains: "example.com")

        get "/u/authorize-email/#{user.email_tokens.last.token}"

        expect(response.status).to eq(200)
        expect(group.reload.users.include?(user)).to eq(true)
      end

      context 'second factor required' do
        let!(:second_factor) { Fabricate(:user_second_factor_totp, user: user) }

        it 'requires a second factor token' do
          get "/u/authorize-email/#{user.email_tokens.last.token}"

          expect(response.status).to eq(200)

          response_body = response.body

          expect(response_body).to include(I18n.t("login.second_factor_title"))
          expect(response_body).not_to include(I18n.t("login.invalid_second_factor_code"))
        end

        it 'adds an error on a second factor attempt' do
          get "/u/authorize-email/#{user.email_tokens.last.token}", params: {
            second_factor_token: "000000",
            second_factor_method: UserSecondFactor.methods[:totp]
          }

          expect(response.status).to eq(200)
          expect(response.body).to include(I18n.t("login.invalid_second_factor_code"))
        end

        it 'confirms with a correct second token' do
          get "/u/authorize-email/#{user.email_tokens.last.token}", params: {
            second_factor_token: ROTP::TOTP.new(second_factor.data).now,
            second_factor_method: UserSecondFactor.methods[:totp]
          }

          expect(response.status).to eq(200)

          response_body = response.body

          expect(response_body).not_to include(I18n.t("login.second_factor_title"))
          expect(response_body).not_to include(I18n.t("login.invalid_second_factor_code"))
        end
      end
    end
  end

  describe '#update' do
    let(:user) { Fabricate(:user) }
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
        let!(:other_user) { Fabricate(:coding_horror) }

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
        let!(:other_user) { Fabricate(:user, email: 'case.insensitive@gmail.com') }

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

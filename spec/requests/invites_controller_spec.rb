require 'rails_helper'

describe InvitesController do
  context 'show' do
    let(:invite) { Fabricate(:invite) }
    let(:user) { Fabricate(:coding_horror) }

    it "returns error if invite not found" do
      get "/invites/nopeNOPEnope"

      expect(response.status).to eq(200)

      body = response.body
      expect(body).to_not have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to include(I18n.t('invite.not_found', site_name: SiteSetting.title, base_url: Discourse.base_url))
    end

    it "renders the accept invite page if invite exists" do
      get "/invites/#{invite.invite_key}"

      expect(response.status).to eq(200)

      body = response.body
      expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to_not include(I18n.t('invite.not_found_template', site_name: SiteSetting.title, base_url: Discourse.base_url))
    end

    it "returns error if invite has already been redeemed" do
      invite.update_attributes!(redeemed_at: 1.day.ago)
      get "/invites/#{invite.invite_key}"

      expect(response.status).to eq(200)

      body = response.body
      expect(body).to_not have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to include(I18n.t('invite.not_found_template', site_name: SiteSetting.title, base_url: Discourse.base_url))
    end
  end

  context '#destroy' do
    it 'requires you to be logged in' do
      delete "/invites.json",
        params: { email: 'jake@adventuretime.ooo' }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let!(:user) { sign_in(Fabricate(:user))      }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'anotheremail@address.com') }

      it 'raises an error when the email is missing' do
        delete "/invites.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when the email cannot be found" do
        delete "/invites.json", params: { email: 'finn@adventuretime.ooo' }
        expect(response.status).to eq(400)
      end

      it 'raises an error when the invite is not yours' do
        delete "/invites.json", params: { email: another_invite.email }
        expect(response.status).to eq(400)
      end

      it "destroys the invite" do
        delete "/invites.json", params: { email: invite.email }
        invite.reload
        expect(invite.trashed?).to be_truthy
      end
    end
  end

  context '#create' do
    it 'requires you to be logged in' do
      post "/invites.json", params: { email: 'jake@adventuretime.ooo' }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        sign_in(Fabricate(:user))
        post "/invites.json", params: { email: email }
        expect(response).to be_forbidden
      end

      it "fails for normal user if invite email already exists" do
        user = sign_in(Fabricate(:trust_level_4))
        invite = Invite.invite_by_email("invite@example.com", user)
        post "/invites.json", params: { email: invite.email }
        expect(response.status).to eq(422)
        json = JSON.parse(response.body)
        expect(json["failed"]).to be_present
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        sign_in(Fabricate(:admin))
        post "/invites.json", params: { email: email, group_names: group.name }
        expect(response.status).to eq(200)
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it 'allows group owners to invite to groups' do
        group = Fabricate(:group)
        user = sign_in(Fabricate(:user))
        user.update!(trust_level: TrustLevel[2])
        group.add_owner(user)

        post "/invites.json", params: { email: email, group_names: group.name }

        expect(response.status).to eq(200)
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it "allows admin to send multiple invites to same email" do
        user = sign_in(Fabricate(:admin))
        invite = Invite.invite_by_email("invite@example.com", user)
        post "/invites.json", params: { email: invite.email }
        expect(response.status).to eq(200)
      end

      it "responds with error message in case of validation failure" do
        sign_in(Fabricate(:admin))
        post "/invites.json", params: { email: "test@mailinator.com" }
        expect(response.status).to eq(422)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end
  end

  context '#create_invite_link' do
    it 'requires you to be logged in' do
      post "/invites/link.json", params: {
        email: 'jake@adventuretime.ooo'
      }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        sign_in(Fabricate(:user))
        post "/invites/link.json", params: { email: email }
        expect(response).to be_forbidden
      end

      it "fails for normal user if invite email already exists" do
        user = sign_in(Fabricate(:trust_level_4))
        invite = Invite.invite_by_email("invite@example.com", user)

        post "/invites/link.json", params: {
          email: invite.email
        }

        expect(response.status).to eq(422)
      end

      it "verifies that inviter is authorized to invite new user to a group-private topic" do
        group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: group)
        group_private_topic = Fabricate(:topic, category: private_category)
        sign_in(Fabricate(:trust_level_4))

        post "/invites/link.json", params: {
          email: email, topic_id: group_private_topic.id
        }

        expect(response).to be_forbidden
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        sign_in(Fabricate(:admin))

        post "/invites/link.json", params: {
          email: email, group_names: group.name
        }

        expect(response.status).to eq(200)
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it "allows multiple group invite" do
        Fabricate(:group, name: "security")
        Fabricate(:group, name: "support")
        sign_in(Fabricate(:admin))

        post "/invites/link.json", params: {
          email: email, group_names: "security,support"
        }

        expect(response.status).to eq(200)
        expect(Invite.find_by(email: email).invited_groups.count).to eq(2)
      end
    end
  end

  context '#perform_accept_invitation' do
    context 'with an invalid invite id' do
      it "redirects to the root and doesn't change the session" do
        put "/invites/show/doesntexist.json"
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(false)
        expect(json["message"]).to eq(I18n.t('invite.not_found'))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'with a deleted invite' do
      let(:topic) { Fabricate(:topic) }

      let(:invite) do
        Invite.invite_by_email("iceking@adventuretime.ooo", topic.user, topic)
      end

      before do
        invite.destroy!
      end

      it "redirects to the root" do
        put "/invites/show/#{invite.invite_key}.json"

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(false)
        expect(json["message"]).to eq(I18n.t('invite.not_found'))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'with a valid invite id' do
      let(:topic) { Fabricate(:topic) }
      let(:invite) do
        Invite.invite_by_email("iceking@adventuretime.ooo", topic.user, topic)
      end

      it 'redeems the invite' do
        put "/invites/show/#{invite.invite_key}.json"
        invite.reload
        expect(invite.redeemed?).to be_truthy
      end

      context 'when redeem returns a user' do
        let(:user) { Fabricate(:coding_horror) }

        context 'success' do
          it 'logs in the user' do
            events = DiscourseEvent.track_events do
              put "/invites/show/#{invite.invite_key}.json"
            end

            expect(events.map { |event| event[:event_name] }).to include(
              :user_logged_in, :user_first_logged_in
            )
            invite.reload
            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(invite.user_id)
            expect(invite.redeemed?).to be_truthy
          end

          it 'redirects to the first topic the user was invited to' do
            put "/invites/show/#{invite.invite_key}.json"
            expect(response.status).to eq(200)
            json = JSON.parse(response.body)
            expect(json["success"]).to eq(true)
            expect(json["redirect_to"]).to eq(topic.relative_url)
          end
        end

        context 'failure' do
          it "doesn't log in the user if there's a validation error" do
            put "/invites/show/#{invite.invite_key}.json", params: { password: "password" }
            expect(response.status).to eq(200)
            json = JSON.parse(response.body)
            expect(json["success"]).to eq(false)
            expect(json["errors"]["password"]).to be_present
          end
        end

        context '.post_process_invite' do
          before do
            SiteSetting.queue_jobs = true
          end

          it 'sends a welcome message if set' do
            user.send_welcome_message = true
            put "/invites/show/#{invite.invite_key}.json"
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)["success"]).to eq(true)

            expect(Jobs::SendSystemMessage.jobs.size).to eq(1)
          end

          context "without password" do
            it "sends password reset email" do
              put "/invites/show/#{invite.invite_key}.json"
              expect(response.status).to eq(200)
              expect(JSON.parse(response.body)["success"]).to eq(true)

              expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(1)
              expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
            end

            it "does not send password reset email if sso is enabled" do
              SiteSetting.sso_url = "https://www.example.com/sso"
              SiteSetting.enable_sso = true
              put "/invites/show/#{invite.invite_key}.json"
              expect(response.status).to eq(200)
              expect(JSON.parse(response.body)["success"]).to eq(true)

              expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
              expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
            end

            it "does not send password reset email if local login is disabled" do
              SiteSetting.enable_local_logins = false
              put "/invites/show/#{invite.invite_key}.json"
              expect(response.status).to eq(200)
              expect(JSON.parse(response.body)["success"]).to eq(true)

              expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
              expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
            end
          end

          context "with password" do
            context "user was invited via email" do
              before { invite.update_column(:via_email, true) }

              it "doesn't send an activation email and activates the user" do
                expect do
                  put "/invites/show/#{invite.invite_key}.json", params: { password: "verystrongpassword" }
                end.to change { UserAuthToken.count }.by(1)

                expect(response.status).to eq(200)
                expect(JSON.parse(response.body)["success"]).to eq(true)

                expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
                expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)

                invited_user = User.find_by_email(invite.email)
                expect(invited_user.active).to eq(true)
                expect(invited_user.email_confirmed?).to eq(true)
              end
            end

            context "user was invited via link" do
              before { invite.update_column(:via_email, false) }

              it "sends an activation email and doesn't activate the user" do
                expect do
                  put "/invites/show/#{invite.invite_key}.json", params: { password: "verystrongpassword" }
                end.not_to change { UserAuthToken.count }

                expect(response.status).to eq(200)
                expect(JSON.parse(response.body)["success"]).to eq(true)
                expect(JSON.parse(response.body)["message"]).to eq(I18n.t("invite.confirm_email"))

                invited_user = User.find_by_email(invite.email)
                expect(invited_user.active).to eq(false)
                expect(invited_user.email_confirmed?).to eq(false)

                expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
                expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)

                tokens = EmailToken.where(user_id: invited_user.id, confirmed: false, expired: false).pluck(:token)
                expect(tokens.size).to eq(1)

                job_args = Jobs::CriticalUserEmail.jobs.first["args"].first
                expect(job_args["type"]).to eq("signup")
                expect(job_args["user_id"]).to eq(invited_user.id)
                expect(job_args["email_token"]).to eq(tokens.first)
              end

            end

          end

        end
      end
    end

    context 'new registrations are disabled' do
      let(:topic) { Fabricate(:topic) }

      let(:invite) do
        Invite.invite_by_email("iceking@adventuretime.ooo", topic.user, topic)
      end

      before { SiteSetting.allow_new_registrations = false }

      it "doesn't redeem the invite" do
        put "/invites/show/#{invite.invite_key}.json"
        expect(response.status).to eq(200)
        invite.reload
        expect(invite.user_id).to be_blank
        expect(invite.redeemed?).to be_falsey
        expect(response.body).to include(I18n.t("login.new_registrations_disabled"))
      end
    end

    context 'user is already logged in' do
      let(:topic) { Fabricate(:topic) }

      let(:invite) do
        Invite.invite_by_email("iceking@adventuretime.ooo", topic.user, topic)
      end

      let!(:user) { sign_in(Fabricate(:user)) }

      it "doesn't redeem the invite" do
        put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
        expect(response.status).to eq(200)
        invite.reload
        expect(invite.user_id).to be_blank
        expect(invite.redeemed?).to be_falsey
        expect(response.body).to include(I18n.t("login.already_logged_in", current_user: user.username))
      end
    end
  end

  context '#resend_invite' do
    it 'requires you to be logged in' do
      post "/invites/reinvite.json", params: { email: 'first_name@example.com' }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let!(:user) { sign_in(Fabricate(:user)) }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'last_name@example.com') }

      it 'raises an error when the email is missing' do
        post "/invites/reinvite.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when the email cannot be found" do
        post "/invites/reinvite.json", params: { email: 'first_name@example.com' }
        expect(response.status).to eq(400)
      end

      it 'raises an error when the invite is not yours' do
        post "/invites/reinvite.json", params: { email: another_invite.email }
        expect(response.status).to eq(400)
      end

      it "resends the invite" do
        SiteSetting.queue_jobs = true
        post "/invites/reinvite.json", params: { email: invite.email }
        expect(response.status).to eq(200)
        expect(Jobs::InviteEmail.jobs.size).to eq(1)
      end
    end
  end

  context '#upload_csv' do
    it 'requires you to be logged in' do
      post "/invites/upload_csv.json"
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/discourse.csv") }

      let(:file) do
        Rack::Test::UploadedFile.new(File.open(csv_file))
      end

      let(:filename) { 'discourse.csv' }

      it "fails if you can't bulk invite to the forum" do
        sign_in(Fabricate(:user))
        post "/invites/upload_csv.json", params: { file: file, name: filename }
        expect(response.status).to eq(403)
      end

      it "allows admin to bulk invite" do
        SiteSetting.queue_jobs = true
        sign_in(Fabricate(:admin))
        post "/invites/upload_csv.json", params: { file: file, name: filename }
        expect(response.status).to eq(200)
        expect(Jobs::BulkInvite.jobs.size).to eq(1)
      end
    end
  end
end

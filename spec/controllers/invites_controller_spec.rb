require 'rails_helper'

describe InvitesController do

  context '.show' do
    render_views

    it "shows error if invite not found" do
      get :show, params: { id: 'nopeNOPEnope' }

      expect(response).to be_success

      body = response.body

      expect(body).to_not have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to include(I18n.t('invite.not_found'))
    end

    it "renders the accept invite page if invite exists" do
      i = Fabricate(:invite)
      get :show, params: { id: i.invite_key }

      expect(response).to be_success

      body = response.body

      expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
      expect(CGI.unescapeHTML(body)).to_not include(I18n.t('invite.not_found'))
    end
  end

  context '.destroy' do

    it 'requires you to be logged in' do
      expect do
        delete :destroy,
          params: { email: 'jake@adventuretime.ooo' },
          format: :json
      end.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'anotheremail@address.com') }

      it 'raises an error when the email is missing' do
        expect { delete :destroy, format: :json }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the email cannot be found" do
        expect do
          delete :destroy, params: { email: 'finn@adventuretime.ooo' }, format: :json
        end.to raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when the invite is not yours' do
        expect do
          delete :destroy, params: { email: another_invite.email }, format: :json
        end.to raise_error(Discourse::InvalidParameters)
      end

      it "destroys the invite" do
        Invite.any_instance.expects(:trash!).with(user)
        delete :destroy, params: { email: invite.email }, format: :json
      end

    end

  end

  context '#create' do
    it 'requires you to be logged in' do
      expect do
        post :create, params: { email: 'jake@adventuretime.ooo' }, format: :json
      end.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        log_in
        post :create, params: { email: email }, format: :json
        expect(response).not_to be_success
      end

      it "fails for normal user if invite email already exists" do
        user = log_in(:trust_level_4)
        invite = Invite.invite_by_email("invite@example.com", user)
        invite.reload
        post :create, params: { email: invite.email }, format: :json
        expect(response).not_to be_success
        json = JSON.parse(response.body)
        expect(json["failed"]).to be_present
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        log_in(:admin)
        post :create, params: { email: email, group_names: group.name }, format: :json
        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it 'allows group owners to invite to groups' do
        group = Fabricate(:group)
        user = log_in
        user.update!(trust_level: TrustLevel[2])
        group.add_owner(user)

        post :create, params: { email: email, group_names: group.name }, format: :json

        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it "allows admin to send multiple invites to same email" do
        user = log_in(:admin)
        invite = Invite.invite_by_email("invite@example.com", user)
        invite.reload
        post :create, params: { email: invite.email }, format: :json
        expect(response).to be_success
      end

      it "responds with error message in case of validation failure" do
        log_in(:admin)
        post :create, params: { email: "test@mailinator.com" }, format: :json
        expect(response).not_to be_success
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

  end

  context '.create_invite_link' do
    it 'requires you to be logged in' do
      expect {
        post :create_invite_link, params: {
          email: 'jake@adventuretime.ooo'
        }, format: :json
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        log_in
        post :create_invite_link, params: { email: email }, format: :json
        expect(response).not_to be_success
      end

      it "fails for normal user if invite email already exists" do
        user = log_in(:trust_level_4)
        invite = Invite.invite_by_email("invite@example.com", user)
        invite.reload

        post :create_invite_link, params: {
          email: invite.email
        }, format: :json

        expect(response).not_to be_success
      end

      it "verifies that inviter is authorized to invite new user to a group-private topic" do
        group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: group)
        group_private_topic = Fabricate(:topic, category: private_category)
        log_in(:trust_level_4)

        post :create_invite_link, params: {
          email: email, topic_id: group_private_topic.id
        }, format: :json

        expect(response).not_to be_success
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        log_in(:admin)

        post :create_invite_link, params: {
          email: email, group_names: group.name
        }, format: :json

        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it "allows multiple group invite" do
        Fabricate(:group, name: "security")
        Fabricate(:group, name: "support")
        log_in(:admin)

        post :create_invite_link, params: {
          email: email, group_names: "security,support"
        }, format: :json

        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(2)
      end
    end
  end

  context '.perform_accept_invitation' do

    context 'with an invalid invite id' do
      before do
        put :perform_accept_invitation, params: { id: "doesn't exist" }, format: :json
      end

      it "redirects to the root" do
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(false)
        expect(json["message"]).to eq(I18n.t('invite.not_found'))
      end

      it "should not change the session" do
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'with a deleted invite' do
      let(:topic) { Fabricate(:topic) }
      let(:invite) { topic.invite_by_email(topic.user, "iceking@adventuretime.ooo") }
      let(:deleted_invite) { invite.destroy; invite }
      before do
        put :perform_accept_invitation, params: { id: deleted_invite.invite_key }, format: :json
      end

      it "redirects to the root" do
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json["success"]).to eq(false)
        expect(json["message"]).to eq(I18n.t('invite.not_found'))
      end

      it "should not change the session" do
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'with a valid invite id' do
      let(:topic) { Fabricate(:topic) }
      let(:invite) { topic.invite_by_email(topic.user, "iceking@adventuretime.ooo") }

      it 'redeems the invite' do
        Invite.any_instance.expects(:redeem)
        put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
      end

      context 'when redeem returns a user' do
        let(:user) { Fabricate(:coding_horror) }

        context 'success' do
          subject { put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json }

          before do
            Invite.any_instance.expects(:redeem).returns(user)
          end

          it 'logs in the user' do
            events = DiscourseEvent.track_events { subject }

            expect(events.map { |event| event[:event_name] }).to include(
              :user_logged_in, :user_first_logged_in
            )

            expect(session[:current_user_id]).to eq(user.id)
          end

          it 'redirects to the first topic the user was invited to' do
            subject
            json = JSON.parse(response.body)
            expect(json["success"]).to eq(true)
            expect(json["redirect_to"]).to eq(topic.relative_url)
          end
        end

        context 'failure' do
          subject { put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json }

          it "doesn't log in the user if there's a validation error" do
            user.errors.add(:password, :common)
            Invite.any_instance.expects(:redeem).raises(ActiveRecord::RecordInvalid.new(user))
            subject
            expect(response).to be_success
            json = JSON.parse(response.body)
            expect(json["success"]).to eq(false)
            expect(json["errors"]["password"]).to be_present
          end
        end

        context '.post_process_invite' do
          before do
            Invite.any_instance.stubs(:redeem).returns(user)
            Jobs.expects(:enqueue).with(:invite_email, has_key(:invite_id))
            user.password_hash = nil
          end

          it 'sends a welcome message if set' do
            user.send_welcome_message = true
            user.expects(:enqueue_welcome_message).with('welcome_invite')
            Jobs.expects(:enqueue).with(:invite_password_instructions_email, has_entries(username: user.username))
            put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
          end

          it "sends password reset email if password is not set" do
            user.expects(:enqueue_welcome_message).with('welcome_invite').never
            Jobs.expects(:enqueue).with(:invite_password_instructions_email, has_entries(username: user.username))
            put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
          end

          it "does not send password reset email if sso is enabled" do
            SiteSetting.enable_sso = true
            Jobs.expects(:enqueue).with(:invite_password_instructions_email, has_key(:username)).never
            put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
          end

          it "does not send password reset email if local login is disabled" do
            SiteSetting.enable_local_logins = false
            Jobs.expects(:enqueue).with(:invite_password_instructions_email, has_key(:username)).never
            put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
          end

          it 'sends an activation email if password is set' do
            user.password_hash = 'qaw3ni3h2wyr63lakw7pea1nrtr44pls'
            Jobs.expects(:enqueue).with(:invite_password_instructions_email, has_key(:username)).never
            Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup, user_id: user.id))
            put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
          end
        end
      end
    end

    context 'new registrations are disabled' do
      let(:topic) { Fabricate(:topic) }
      let(:invite) { topic.invite_by_email(topic.user, "iceking@adventuretime.ooo") }
      before { SiteSetting.allow_new_registrations = false }

      it "doesn't redeem the invite" do
        Invite.any_instance.stubs(:redeem).never
        put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
      end
    end

    context 'user is already logged in' do
      let!(:user) { log_in }
      let(:topic) { Fabricate(:topic) }
      let(:invite) { topic.invite_by_email(topic.user, "iceking@adventuretime.ooo") }

      it "doesn't redeem the invite" do
        Invite.any_instance.stubs(:redeem).never
        put :perform_accept_invitation, params: { id: invite.invite_key }, format: :json
      end
    end
  end

  context '.resend_invite' do

    it 'requires you to be logged in' do
      expect {
        delete :resend_invite, params: { email: 'first_name@example.com' }, format: :json
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'last_name@example.com') }

      it 'raises an error when the email is missing' do
        expect { post :resend_invite, format: :json }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the email cannot be found" do
        expect do
          post :resend_invite, params: { email: 'first_name@example.com' }, format: :json
        end.to raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when the invite is not yours' do
        expect do
          post :resend_invite, params: { email: another_invite.email }, format: :json
        end.to raise_error(Discourse::InvalidParameters)
      end

      it "resends the invite" do
        Invite.any_instance.expects(:resend_invite)
        post :resend_invite, params: { email: invite.email }, format: :json
      end

    end

  end

  context '.upload_csv' do
    it 'requires you to be logged in' do
      expect {
        post :upload_csv, format: :json
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/discourse.csv") }

      let(:file) do
        Rack::Test::UploadedFile.new(File.open(csv_file))
      end

      let(:filename) { 'discourse.csv' }

      it "fails if you can't bulk invite to the forum" do
        log_in
        post :upload_csv, params: { file: file, name: filename }, format: :json
        expect(response).not_to be_success
      end

      it "allows admin to bulk invite" do
        log_in(:admin)
        post :upload_csv, params: { file: file, name: filename }, format: :json
        expect(response).to be_success
      end
    end

  end

end

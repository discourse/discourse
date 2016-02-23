require 'rails_helper'

describe InvitesController do

  context '.destroy' do

    it 'requires you to be logged in' do
      expect {
        delete :destroy, email: 'jake@adventuretime.ooo'
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'anotheremail@address.com') }


      it 'raises an error when the email is missing' do
        expect { delete :destroy }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the email cannot be found" do
        expect { delete :destroy, email: 'finn@adventuretime.ooo' }.to raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when the invite is not yours' do
        expect { delete :destroy, email: another_invite.email }.to raise_error(Discourse::InvalidParameters)
      end

      it "destroys the invite" do
        Invite.any_instance.expects(:trash!).with(user)
        delete :destroy, email: invite.email
      end

    end

  end

  context '.create' do
    it 'requires you to be logged in' do
      expect {
        post :create, email: 'jake@adventuretime.ooo'
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        log_in
        post :create, email: email
        expect(response).not_to be_success
      end

      it "fails for normal user if invite email already exists" do
        user = log_in(:trust_level_4)
        invite = Invite.invite_by_email("invite@example.com", user)
        invite.reload
        post :create, email: invite.email
        expect(response).not_to be_success
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        log_in(:admin)
        post :create, email: email, group_names: group.name
        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it "allows admin to send multiple invites to same email" do
        user = log_in(:admin)
        invite = Invite.invite_by_email("invite@example.com", user)
        invite.reload
        post :create, email: invite.email
        expect(response).to be_success
      end
    end

  end

  context '.create_invite_link' do
    it 'requires you to be logged in' do
      expect {
        post :create_invite_link, email: 'jake@adventuretime.ooo'
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        log_in
        post :create_invite_link, email: email
        expect(response).not_to be_success
      end

      it "fails for normal user if invite email already exists" do
        user = log_in(:trust_level_4)
        invite = Invite.invite_by_email("invite@example.com", user)
        invite.reload
        post :create_invite_link, email: invite.email
        expect(response).not_to be_success
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        log_in(:admin)
        post :create_invite_link, email: email, group_names: group.name
        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(1)
      end

      it "allows multiple group invite" do
        group_1 = Fabricate(:group, name: "security")
        group_2 = Fabricate(:group, name: "support")
        log_in(:admin)
        post :create_invite_link, email: email, group_names: "security,support"
        expect(response).to be_success
        expect(Invite.find_by(email: email).invited_groups.count).to eq(2)
      end
    end
  end

  context '.show' do

    context 'with an invalid invite id' do
      before do
        get :show, id: "doesn't exist"
      end

      it "redirects to the root" do
        expect(response).to redirect_to("/")
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
        get :show, id: deleted_invite.invite_key
      end

      it "redirects to the root" do
        expect(response).to redirect_to("/")
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
        get :show, id: invite.invite_key
      end

      context 'when redeem returns a user' do
        let(:user) { Fabricate(:coding_horror) }

        context 'success' do
          before do
            Invite.any_instance.expects(:redeem).returns(user)
            get :show, id: invite.invite_key
          end

          it 'logs in the user' do
            expect(session[:current_user_id]).to eq(user.id)
          end

          it 'redirects to the first topic the user was invited to' do
            expect(response).to redirect_to(topic.relative_url)
          end
        end

        context 'welcome message' do
          before do
            Invite.any_instance.stubs(:redeem).returns(user)
            Jobs.expects(:enqueue).with(:invite_email, has_key(:invite_id))
          end

          it 'sends a welcome message if set' do
            user.send_welcome_message = true
            user.expects(:enqueue_welcome_message).with('welcome_invite')
            get :show, id: invite.invite_key
          end

          it "doesn't send a welcome message if not set" do
            user.expects(:enqueue_welcome_message).with('welcome_invite').never
            get :show, id: invite.invite_key
          end

        end

      end

    end

    context 'new registrations are disabled' do
      let(:topic) { Fabricate(:topic) }
      let(:invite) { topic.invite_by_email(topic.user, "iceking@adventuretime.ooo") }
      before { SiteSetting.stubs(:allow_new_registrations).returns(false) }

      it "doesn't redeem the invite" do
        Invite.any_instance.stubs(:redeem).never
        get :show, id: invite.invite_key
      end
    end

    context 'user is already logged in' do
      let!(:user) { log_in }
      let(:topic) { Fabricate(:topic) }
      let(:invite) { topic.invite_by_email(topic.user, "iceking@adventuretime.ooo") }

      it "doesn't redeem the invite" do
        Invite.any_instance.stubs(:redeem).never
        get :show, id: invite.invite_key
      end
    end
  end

  context '.create_disposable_invite' do
    it 'requires you to be logged in' do
      expect {
        post :create, email: 'jake@adventuretime.ooo'
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in as normal user' do
      let(:user) { Fabricate(:user) }

      it "does not create disposable invitation" do
        log_in
        post :create_disposable_invite, email: user.email
        expect(response).not_to be_success
      end
    end

    context 'while logged in as admin' do
      before do
        log_in(:admin)
      end
      let(:user) { Fabricate(:user) }

      it "creates disposable invitation" do
        post :create_disposable_invite, email: user.email
        expect(response).to be_success
        expect(Invite.where(invited_by_id: user.id).count).to eq(1)
      end

      it "creates multiple disposable invitations" do
        post :create_disposable_invite, email: user.email, quantity: 10
        expect(response).to be_success
        expect(Invite.where(invited_by_id: user.id).count).to eq(10)
      end

      it "allows group invite" do
        group = Fabricate(:group)
        post :create_disposable_invite, email: user.email, group_names: group.name
        expect(response).to be_success
        expect(Invite.find_by(invited_by_id: user.id).invited_groups.count).to eq(1)
      end

      it "allows multiple group invite" do
        group_1 = Fabricate(:group, name: "security")
        group_2 = Fabricate(:group, name: "support")
        post :create_disposable_invite, email: user.email, group_names: "security,support"
        expect(response).to be_success
        expect(Invite.find_by(invited_by_id: user.id).invited_groups.count).to eq(2)
      end

    end

  end

  context '.redeem_disposable_invite' do

    context 'with an invalid invite token' do
      before do
        get :redeem_disposable_invite, email: "name@example.com", token: "doesn't exist"
      end

      it "redirects to the root" do
        expect(response).to redirect_to("/")
      end

      it "should not change the session" do
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'with a valid invite token' do
      let(:topic) { Fabricate(:topic) }
      let(:invitee) { Fabricate(:user) }
      let(:invite) { Invite.create!(invited_by: invitee) }

      it 'converts "space" to "+" in email parameter' do
        Invite.expects(:redeem_from_token).with(invite.invite_key, "fname+lname@example.com", nil, nil, topic.id)
        get :redeem_disposable_invite, email: "fname lname@example.com", token: invite.invite_key, topic: topic.id
      end

      it 'redeems the invite' do
        Invite.expects(:redeem_from_token).with(invite.invite_key, "name@example.com", nil, nil, topic.id)
        get :redeem_disposable_invite, email: "name@example.com", token: invite.invite_key, topic: topic.id
      end

      context 'when redeem returns a user' do
        let(:user) { Fabricate(:user) }

        before do
          Invite.expects(:redeem_from_token).with(invite.invite_key, user.email, nil, nil, topic.id).returns(user)
          get :redeem_disposable_invite, email: user.email, token: invite.invite_key, topic: topic.id
        end

        it 'logs in user' do
          expect(session[:current_user_id]).to eq(user.id)
        end

      end

    end

  end

  context '.resend_invite' do

    it 'requires you to be logged in' do
      expect {
        delete :resend_invite, email: 'first_name@example.com'
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'last_name@example.com') }

      it 'raises an error when the email is missing' do
        expect { post :resend_invite }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the email cannot be found" do
        expect { post :resend_invite, email: 'first_name@example.com' }.to raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when the invite is not yours' do
        expect { post :resend_invite, email: another_invite.email }.to raise_error(Discourse::InvalidParameters)
      end

      it "resends the invite" do
        Invite.any_instance.expects(:resend_invite)
        post :resend_invite, email: invite.email
      end

    end

  end

  context '.check_csv_chunk' do
    it 'requires you to be logged in' do
      expect {
        post :check_csv_chunk
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:resumableChunkNumber) { 1 }
      let(:resumableCurrentChunkSize) { 46 }
      let(:resumableIdentifier) { '46-discoursecsv' }
      let(:resumableFilename) { 'discourse.csv' }

      it "fails if you can't bulk invite to the forum" do
        log_in
        post :check_csv_chunk, resumableChunkNumber: resumableChunkNumber, resumableCurrentChunkSize: resumableCurrentChunkSize.to_i, resumableIdentifier: resumableIdentifier, resumableFilename: resumableFilename
        expect(response).not_to be_success
      end

    end

  end

  context '.upload_csv_chunk' do
    it 'requires you to be logged in' do
      expect {
        post :upload_csv_chunk
      }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/discourse.csv") }
      let(:file) do
        ActionDispatch::Http::UploadedFile.new({ filename: 'discourse.csv', tempfile: csv_file })
      end
      let(:resumableChunkNumber) { 1 }
      let(:resumableChunkSize) { 1048576 }
      let(:resumableCurrentChunkSize) { 46 }
      let(:resumableTotalSize) { 46 }
      let(:resumableType) { 'text/csv' }
      let(:resumableIdentifier) { '46-discoursecsv' }
      let(:resumableFilename) { 'discourse.csv' }
      let(:resumableRelativePath) { 'discourse.csv' }

      it "fails if you can't bulk invite to the forum" do
        log_in
        post :upload_csv_chunk, file: file, resumableChunkNumber: resumableChunkNumber.to_i, resumableChunkSize: resumableChunkSize.to_i, resumableCurrentChunkSize: resumableCurrentChunkSize.to_i, resumableTotalSize: resumableTotalSize.to_i, resumableType: resumableType, resumableIdentifier: resumableIdentifier, resumableFilename: resumableFilename
        expect(response).not_to be_success
      end

      it "allows admins to bulk invite" do
        log_in(:admin)
        post :upload_csv_chunk, file: file, resumableChunkNumber: resumableChunkNumber.to_i, resumableChunkSize: resumableChunkSize.to_i, resumableCurrentChunkSize: resumableCurrentChunkSize.to_i, resumableTotalSize: resumableTotalSize.to_i, resumableType: resumableType, resumableIdentifier: resumableIdentifier, resumableFilename: resumableFilename
        expect(response).to be_success
      end

    end

  end

end

require 'spec_helper'

describe InvitesController do

  context '.destroy' do

    it 'requires you to be logged in' do
      lambda {
        delete :destroy, email: 'jake@adventuretime.ooo'
      }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }
      let!(:invite) { Fabricate(:invite, invited_by: user) }
      let(:another_invite) { Fabricate(:invite, email: 'anotheremail@address.com') }


      it 'raises an error when the email is missing' do
        lambda { delete :destroy }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the email cannot be found" do
        lambda { delete :destroy, email: 'finn@adventuretime.ooo' }.should raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when the invite is not yours' do
        lambda { delete :destroy, email: another_invite.email }.should raise_error(Discourse::InvalidParameters)
      end

      it "destroys the invite" do
        Invite.any_instance.expects(:trash!).with(user)
        delete :destroy, email: invite.email
      end

    end

  end

  context '.create' do
    it 'requires you to be logged in' do
      lambda {
        post :create, email: 'jake@adventuretime.ooo'
      }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:email) { 'jake@adventuretime.ooo' }

      it "fails if you can't invite to the forum" do
        log_in
        post :create, email: email
        response.should_not be_success
      end

      it "allows admins to invite to groups" do
        group = Fabricate(:group)
        log_in(:admin)
        post :create, email: email, group_names: group.name
        response.should be_success
        Invite.find_by(email: email).invited_groups.count.should == 1
      end
    end

  end

  context '.show' do

    context 'with an invalid invite id' do
      before do
        get :show, id: "doesn't exist"
      end

      it "redirects to the root" do
        response.should redirect_to("/")
      end

      it "should not change the session" do
        session[:current_user_id].should be_blank
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
        response.should redirect_to("/")
      end

      it "should not change the session" do
        session[:current_user_id].should be_blank
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
            session[:current_user_id].should == user.id
          end

          it 'redirects to the first topic the user was invited to' do
            response.should redirect_to(topic.relative_url)
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

  end

  context '.check_csv_chunk' do
    it 'requires you to be logged in' do
      lambda {
        post :check_csv_chunk
      }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let(:resumableChunkNumber) { 1 }
      let(:resumableCurrentChunkSize) { 46 }
      let(:resumableIdentifier) { '46-discoursecsv' }
      let(:resumableFilename) { 'discourse.csv' }

      it "fails if you can't bulk invite to the forum" do
        log_in
        post :check_csv_chunk, resumableChunkNumber: resumableChunkNumber, resumableCurrentChunkSize: resumableCurrentChunkSize.to_i, resumableIdentifier: resumableIdentifier, resumableFilename: resumableFilename
        response.should_not be_success
      end

    end

  end

  context '.upload_csv_chunk' do
    it 'requires you to be logged in' do
      lambda {
        post :upload_csv_chunk
      }.should raise_error(Discourse::NotLoggedIn)
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
        response.should_not be_success
      end

      it "allows admins to bulk invite" do
        log_in(:admin)
        post :upload_csv_chunk, file: file, resumableChunkNumber: resumableChunkNumber.to_i, resumableChunkSize: resumableChunkSize.to_i, resumableCurrentChunkSize: resumableCurrentChunkSize.to_i, resumableTotalSize: resumableTotalSize.to_i, resumableType: resumableType, resumableIdentifier: resumableIdentifier, resumableFilename: resumableFilename
        response.should be_success
      end

    end

  end

end

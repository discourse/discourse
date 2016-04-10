require 'rails_helper'
require_dependency 'single_sign_on'

describe Admin::UsersController do

  it 'is a subclass of AdminController' do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.index' do
      it 'returns success' do
        xhr :get, :index
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        expect(::JSON.parse(response.body)).to be_present
      end

      context 'when showing emails' do

        it "returns email for all the users" do
          xhr :get, :index, show_emails: "true"
          data = ::JSON.parse(response.body)
          data.each do |user|
            expect(user["email"]).to be_present
          end
        end

        it "logs only 1 enty" do
          expect(UserHistory.where(action: UserHistory.actions[:check_email], acting_user_id: @user.id).count).to eq(0)

          xhr :get, :index, show_emails: "true"

          expect(UserHistory.where(action: UserHistory.actions[:check_email], acting_user_id: @user.id).count).to eq(1)
        end

      end
    end

    describe '.show' do
      context 'an existing user' do
        it 'returns success' do
          xhr :get, :show, id: @user.id
          expect(response).to be_success
        end
      end

      context 'an existing user' do
        it 'returns success' do
          xhr :get, :show, id: 0
          expect(response).not_to be_success
        end
      end
    end

    context '.approve_bulk' do

      let(:evil_trout) { Fabricate(:evil_trout) }

      it "does nothing without uesrs" do
        User.any_instance.expects(:approve).never
        xhr :put, :approve_bulk
      end

      it "won't approve the user when not allowed" do
        Guardian.any_instance.expects(:can_approve?).with(evil_trout).returns(false)
        User.any_instance.expects(:approve).never
        xhr :put, :approve_bulk, users: [evil_trout.id]
      end

      it "approves the user when permitted" do
        Guardian.any_instance.expects(:can_approve?).with(evil_trout).returns(true)
        User.any_instance.expects(:approve).once
        xhr :put, :approve_bulk, users: [evil_trout.id]
      end

    end

    context '.generate_api_key' do
      let(:evil_trout) { Fabricate(:evil_trout) }

      it 'calls generate_api_key' do
        User.any_instance.expects(:generate_api_key).with(@user)
        xhr :post, :generate_api_key, user_id: evil_trout.id
      end
    end

    context '.revoke_api_key' do

      let(:evil_trout) { Fabricate(:evil_trout) }

      it 'calls revoke_api_key' do
        User.any_instance.expects(:revoke_api_key)
        xhr :delete, :revoke_api_key, user_id: evil_trout.id
      end

    end

    context '.approve' do

      let(:evil_trout) { Fabricate(:evil_trout) }

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_approve?).with(evil_trout).returns(false)
        xhr :put, :approve, user_id: evil_trout.id
        expect(response).to be_forbidden
      end

      it 'calls approve' do
        User.any_instance.expects(:approve).with(@user)
        xhr :put, :approve, user_id: evil_trout.id
      end

    end

    context '.suspend' do

      let(:evil_trout) { Fabricate(:evil_trout) }

      it "also revoke any api keys" do
        User.any_instance.expects(:revoke_api_key)
        xhr :put, :suspend, user_id: evil_trout.id
      end

    end

    context '.revoke_admin' do
      before do
        @another_admin = Fabricate(:admin)
      end

      it 'raises an error unless the user can revoke access' do
        Guardian.any_instance.expects(:can_revoke_admin?).with(@another_admin).returns(false)
        xhr :put, :revoke_admin, user_id: @another_admin.id
        expect(response).to be_forbidden
      end

      it 'updates the admin flag' do
        xhr :put, :revoke_admin, user_id: @another_admin.id
        @another_admin.reload
        expect(@another_admin).not_to be_admin
      end
    end

    context '.grant_admin' do
      before do
        @another_user = Fabricate(:coding_horror)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_grant_admin?).with(@another_user).returns(false)
        xhr :put, :grant_admin, user_id: @another_user.id
        expect(response).to be_forbidden
      end

      it "returns a 404 if the username doesn't exist" do
        xhr :put, :grant_admin, user_id: 123123
        expect(response).to be_forbidden
      end

      it 'updates the admin flag' do
        xhr :put, :grant_admin, user_id: @another_user.id
        @another_user.reload
        expect(@another_user).to be_admin
      end
    end

    context '.add_group' do
      let(:user) { Fabricate(:user) }
      let(:group) { Fabricate(:group) }

      it 'adds the user to the group' do
        xhr :post, :add_group, group_id: group.id, user_id: user.id
        expect(response).to be_success

        expect(GroupUser.where(user_id: user.id, group_id: group.id).exists?).to eq(true)

        # Doing it again doesn't raise an error
        xhr :post, :add_group, group_id: group.id, user_id: user.id
        expect(response).to be_success
      end
    end

    context '.primary_group' do
      before do
        @another_user = Fabricate(:coding_horror)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_change_primary_group?).with(@another_user).returns(false)
        xhr :put, :primary_group, user_id: @another_user.id
        expect(response).to be_forbidden
      end

      it "returns a 404 if the user doesn't exist" do
        xhr :put, :primary_group, user_id: 123123
        expect(response).to be_forbidden
      end

      it "changes the user's primary group" do
        xhr :put, :primary_group, user_id: @another_user.id, primary_group_id: 2
        @another_user.reload
        expect(@another_user.primary_group_id).to eq(2)
      end
    end

    context '.trust_level' do
      before do
        @another_user = Fabricate(:coding_horror, created_at: 1.month.ago)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_change_trust_level?).with(@another_user).returns(false)
        xhr :put, :trust_level, user_id: @another_user.id
        expect(response).not_to be_success
      end

      it "returns a 404 if the username doesn't exist" do
        xhr :put, :trust_level, user_id: 123123
        expect(response).not_to be_success
      end

      it "upgrades the user's trust level" do
        StaffActionLogger.any_instance.expects(:log_trust_level_change).with(@another_user, @another_user.trust_level, 2).once
        xhr :put, :trust_level, user_id: @another_user.id, level: 2
        @another_user.reload
        expect(@another_user.trust_level).to eq(2)
        expect(response).to be_success
      end

      it "raises no error when demoting a user below their current trust level (locks trust level)" do
        stat = @another_user.user_stat
        stat.topics_entered = SiteSetting.tl1_requires_topics_entered + 1
        stat.posts_read_count = SiteSetting.tl1_requires_read_posts + 1
        stat.time_read = SiteSetting.tl1_requires_time_spent_mins * 60
        stat.save!
        @another_user.update_attributes(trust_level: TrustLevel[1])
        xhr :put, :trust_level, user_id: @another_user.id, level: TrustLevel[0]
        expect(response).to be_success
        @another_user.reload
        expect(@another_user.trust_level_locked).to eq(true)
      end
    end

    describe '.revoke_moderation' do
      before do
        @moderator = Fabricate(:moderator)
      end

      it 'raises an error unless the user can revoke access' do
        Guardian.any_instance.expects(:can_revoke_moderation?).with(@moderator).returns(false)
        xhr :put, :revoke_moderation, user_id: @moderator.id
        expect(response).to be_forbidden
      end

      it 'updates the moderator flag' do
        xhr :put, :revoke_moderation, user_id: @moderator.id
        @moderator.reload
        expect(@moderator.moderator).not_to eq(true)
      end
    end

    context '.grant_moderation' do
      before do
        @another_user = Fabricate(:coding_horror)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_grant_moderation?).with(@another_user).returns(false)
        xhr :put, :grant_moderation, user_id: @another_user.id
        expect(response).to be_forbidden
      end

      it "returns a 404 if the username doesn't exist" do
        xhr :put, :grant_moderation, user_id: 123123
        expect(response).to be_forbidden
      end

      it 'updates the moderator flag' do
        xhr :put, :grant_moderation, user_id: @another_user.id
        @another_user.reload
        expect(@another_user.moderator).to eq(true)
      end
    end

    context '.reject_bulk' do
      let(:reject_me)     { Fabricate(:user) }
      let(:reject_me_too) { Fabricate(:user) }

      it 'does nothing without users' do
        UserDestroyer.any_instance.expects(:destroy).never
        xhr :delete, :reject_bulk
      end

      it "won't delete users if not allowed" do
        Guardian.any_instance.stubs(:can_delete_user?).returns(false)
        UserDestroyer.any_instance.expects(:destroy).never
        xhr :delete, :reject_bulk, users: [reject_me.id]
      end

      it "reports successes" do
        Guardian.any_instance.stubs(:can_delete_user?).returns(true)
        UserDestroyer.any_instance.stubs(:destroy).returns(true)
        xhr :delete, :reject_bulk, users: [reject_me.id, reject_me_too.id]
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['success'].to_i).to eq(2)
        expect(json['failed'].to_i).to eq(0)
      end

      context 'failures' do
        before do
          Guardian.any_instance.stubs(:can_delete_user?).returns(true)
        end

        it 'can handle some successes and some failures' do
          UserDestroyer.any_instance.stubs(:destroy).with(reject_me, anything).returns(false)
          UserDestroyer.any_instance.stubs(:destroy).with(reject_me_too, anything).returns(true)
          xhr :delete, :reject_bulk, users: [reject_me.id, reject_me_too.id]
          expect(response).to be_success
          json = ::JSON.parse(response.body)
          expect(json['success'].to_i).to eq(1)
          expect(json['failed'].to_i).to eq(1)
        end

        it 'reports failure due to a user still having posts' do
          UserDestroyer.any_instance.expects(:destroy).with(reject_me, anything).raises(UserDestroyer::PostsExistError)
          xhr :delete, :reject_bulk, users: [reject_me.id]
          expect(response).to be_success
          json = ::JSON.parse(response.body)
          expect(json['success'].to_i).to eq(0)
          expect(json['failed'].to_i).to eq(1)
        end
      end
    end

    context '.destroy' do
      before do
        @delete_me = Fabricate(:user)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_delete_user?).with(@delete_me).returns(false)
        xhr :delete, :destroy, id: @delete_me.id
        expect(response).to be_forbidden
      end

      it "returns a 403 if the user doesn't exist" do
        xhr :delete, :destroy, id: 123123
        expect(response).to be_forbidden
      end

      context "user has post" do

        before do
          @user = Fabricate(:user)
          topic = create_topic(user: @user)
          _post = create_post(topic: topic, user: @user)
          @user.stubs(:first_post_created_at).returns(Time.zone.now)
          User.expects(:find_by).with(id: @delete_me.id).returns(@user)
        end

        it "returns an error" do
          xhr :delete, :destroy, id: @delete_me.id
          expect(response).to be_forbidden
        end

        it "doesn't return an error if delete_posts == true" do
          UserDestroyer.any_instance.expects(:destroy).with(@user, has_entry('delete_posts' => true)).returns(true)
          xhr :delete, :destroy, id: @delete_me.id, delete_posts: true
          expect(response).to be_success
        end

      end

      it "deletes the user record" do
        UserDestroyer.any_instance.expects(:destroy).returns(true)
        xhr :delete, :destroy, id: @delete_me.id
      end
    end

    context 'activate' do
      before do
        @reg_user = Fabricate(:inactive_user)
      end

      it "returns success" do
        xhr :put, :activate, user_id: @reg_user.id
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['success']).to eq("OK")
      end
    end

    context 'log_out' do
      before do
        @reg_user = Fabricate(:user)
      end

      it "returns success" do
        xhr :put, :log_out, user_id: @reg_user.id
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['success']).to eq("OK")
      end

      it "returns 404 when user_id does not exist" do
        xhr :put, :log_out, user_id: 123123
        expect(response).not_to be_success
      end
    end

    context 'block' do
      before do
        @reg_user = Fabricate(:user)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_block_user?).with(@reg_user).returns(false)
        UserBlocker.expects(:block).never
        xhr :put, :block, user_id: @reg_user.id
        expect(response).to be_forbidden
      end

      it "returns a 403 if the user doesn't exist" do
        xhr :put, :block, user_id: 123123
        expect(response).to be_forbidden
      end

      it "punishes the user for spamming" do
        UserBlocker.expects(:block).with(@reg_user, @user, anything)
        xhr :put, :block, user_id: @reg_user.id
      end
    end

    context 'unblock' do
      before do
        @reg_user = Fabricate(:user)
      end

      it "raises an error when the user doesn't have permission" do
        Guardian.any_instance.expects(:can_unblock_user?).with(@reg_user).returns(false)
        xhr :put, :unblock, user_id: @reg_user.id
        expect(response).to be_forbidden
      end

      it "returns a 403 if the user doesn't exist" do
        xhr :put, :unblock, user_id: 123123
        expect(response).to be_forbidden
      end

      it "punishes the user for spamming" do
        UserBlocker.expects(:unblock).with(@reg_user, @user, anything)
        xhr :put, :unblock, user_id: @reg_user.id
      end
    end

    context 'ip-info' do

      it "uses ipinfo.io webservice to retrieve the info" do
        Excon.expects(:get).with("http://ipinfo.io/123.123.123.123/json", read_timeout: 30, connect_timeout: 30)
        xhr :get, :ip_info, ip: "123.123.123.123"
      end

    end

    context "delete_other_accounts_with_same_ip" do

      it "works" do
        Fabricate(:user, ip_address: "42.42.42.42")
        Fabricate(:user, ip_address: "42.42.42.42")

        UserDestroyer.any_instance.expects(:destroy).twice

        xhr :delete, :delete_other_accounts_with_same_ip, ip: "42.42.42.42", exclude: -1, order: "trust_level DESC"
      end

    end

    context ".invite_admin" do
      it 'should invite admin' do
        Jobs.expects(:enqueue).with(:critical_user_email, anything).returns(true)
        xhr :post, :invite_admin, name: 'Bill', username: 'bill22', email: 'bill@bill.com'
        expect(response).to be_success

        u = User.find_by(email: 'bill@bill.com')
        expect(u.name).to eq("Bill")
        expect(u.username).to eq("bill22")
        expect(u.admin).to eq(true)
      end

      it "doesn't send the email with send_email falsy" do
        Jobs.expects(:enqueue).with(:user_email, anything).never
        xhr :post, :invite_admin, name: 'Bill', username: 'bill22', email: 'bill@bill.com', send_email: '0'
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["password_url"]).to be_present
      end
    end

  end


  context '#sync_sso' do
    let(:sso) { SingleSignOn.new }
    let(:sso_secret) { "sso secret" }

    before do
      log_in(:admin)

      SiteSetting.enable_sso = true
      SiteSetting.sso_overrides_email = true
      SiteSetting.sso_overrides_name = true
      SiteSetting.sso_overrides_username = true
      SiteSetting.sso_secret = sso_secret
      sso.sso_secret = sso_secret
    end


    it 'can sync up with the sso' do
      sso.name = "Bob The Bob"
      sso.username = "bob"
      sso.email = "bob@bob.com"
      sso.external_id = "1"

      user = DiscourseSingleSignOn.parse(sso.payload)
                                  .lookup_or_create_user

      sso.name = "Bill"
      sso.username = "Hokli$$!!"
      sso.email = "bob2@bob.com"

      xhr :post, :sync_sso, Rack::Utils.parse_query(sso.payload)
      expect(response).to be_success

      user.reload
      expect(user.email).to eq("bob2@bob.com")
      expect(user.name).to eq("Bill")
      expect(user.username).to eq("Hokli")
    end

    it 'should create new users' do
      sso.name = "Dr. Claw"
      sso.username = "dr_claw"
      sso.email = "dr@claw.com"
      sso.external_id = "2"
      xhr :post, :sync_sso, Rack::Utils.parse_query(sso.payload)
      expect(response).to be_success

      user = User.where(email: 'dr@claw.com').first
      expect(user).to be_present
      expect(user.ip_address).to be_blank
    end

    it 'should return the right message if the record is invalid' do
      sso.email = ""
      sso.name = ""
      sso.external_id = "1"

      xhr :post, :sync_sso, Rack::Utils.parse_query(sso.payload)
      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)["message"]).to include("Email can't be blank")
    end
  end
end

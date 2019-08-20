# frozen_string_literal: true

require 'rails_helper'
require 'discourse_ip_info'

RSpec.describe Admin::UsersController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  it 'is a subclass of AdminController' do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  before do
    sign_in(admin)
  end

  describe '#index' do
    it 'returns success with JSON' do
      get "/admin/users/list.json"
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to be_present
    end

    context 'when showing emails' do
      it "returns email for all the users" do
        get "/admin/users/list.json", params: { show_emails: "true" }
        expect(response.status).to eq(200)
        data = ::JSON.parse(response.body)
        data.each do |user|
          expect(user["email"]).to be_present
        end
      end

      it "logs only 1 enty" do
        expect do
          get "/admin/users/list.json", params: { show_emails: "true" }
        end.to change { UserHistory.where(action: UserHistory.actions[:check_email], acting_user_id: admin.id).count }.by(1)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#show' do
    context 'an existing user' do
      it 'returns success' do
        get "/admin/users/#{user.id}.json"
        expect(response.status).to eq(200)
      end
    end

    context 'a non-existing user' do
      it 'returns 404 error' do
        get "/admin/users/0.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe '#approve' do
    let(:evil_trout) { Fabricate(:evil_trout) }
    before do
      SiteSetting.must_approve_users = true
    end

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{evil_trout.id}/approve.json"
      expect(response.status).to eq(404)
      evil_trout.reload
      expect(evil_trout.approved).to eq(false)
    end

    it "will create a reviewable if one does not exist" do
      evil_trout.update!(active: true)
      expect(ReviewableUser.find_by(target: evil_trout)).to be_blank
      put "/admin/users/#{evil_trout.id}/approve.json"
      expect(response.code).to eq("200")
      expect(ReviewableUser.find_by(target: evil_trout)).to be_present
      expect(evil_trout.reload).to be_approved
    end

    it 'calls approve' do
      Jobs.run_immediately!
      evil_trout.activate
      put "/admin/users/#{evil_trout.id}/approve.json"
      expect(response.status).to eq(200)
      evil_trout.reload
      expect(evil_trout.approved).to eq(true)
      expect(UserHistory.where(action: UserHistory.actions[:approve_user], target_user_id: evil_trout.id).count).to eq(1)
    end
  end

  describe '#approve_bulk' do
    before do
      SiteSetting.must_approve_users = true
    end

    let(:evil_trout) { Fabricate(:evil_trout) }

    it "does nothing without uesrs" do
      put "/admin/users/approve-bulk.json"
      evil_trout.reload
      expect(response.status).to eq(200)
      expect(evil_trout.approved).to eq(false)
    end

    it "won't approve the user when not allowed" do
      sign_in(user)
      put "/admin/users/approve-bulk.json", params: { users: [evil_trout.id] }
      expect(response.status).to eq(404)
      evil_trout.reload
      expect(evil_trout.approved).to eq(false)
    end

    it "approves the user when permitted" do
      Jobs.run_immediately!
      evil_trout.activate
      put "/admin/users/approve-bulk.json", params: { users: [evil_trout.id] }
      expect(response.status).to eq(200)
      evil_trout.reload
      expect(evil_trout.approved).to eq(true)
    end
  end

  describe '#generate_api_key' do
    it 'calls generate_api_key' do
      post "/admin/users/#{user.id}/generate_api_key.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["api_key"]["user"]["id"]).to eq(user.id)
      expect(json["api_key"]["key"]).to be_present
    end
  end

  describe '#revoke_api_key' do
    it 'calls revoke_api_key' do
      ApiKey.create!(user: user, key: SecureRandom.hex)
      delete "/admin/users/#{user.id}/revoke_api_key.json"
      expect(response.status).to eq(200)
      expect(ApiKey.where(user: user).count).to eq(0)
    end
  end

  describe '#suspend' do
    fab!(:post) { Fabricate(:post) }
    let(:suspend_params) do
      { suspend_until: 5.hours.from_now,
        reason: "because of this post",
        post_id: post.id }
    end

    it "works properly" do
      expect(user).not_to be_suspended
      put "/admin/users/#{user.id}/suspend.json", params: {
        suspend_until: 5.hours.from_now,
        reason: "because I said so"
      }

      expect(response.status).to eq(200)

      user.reload
      expect(user).to be_suspended
      expect(user.suspended_at).to be_present
      expect(user.suspended_till).to be_present

      log = UserHistory.where(target_user_id: user.id).order('id desc').first
      expect(log.details).to match(/because I said so/)
    end

    context "with an associated post" do
      it "can have an associated post" do
        put "/admin/users/#{user.id}/suspend.json", params: suspend_params

        expect(response.status).to eq(200)

        log = UserHistory.where(target_user_id: user.id).order('id desc').first
        expect(log.post_id).to eq(post.id)
      end

      it "can delete an associated post" do
        put "/admin/users/#{user.id}/suspend.json", params: suspend_params.merge(post_action: 'delete')
        post.reload
        expect(post.deleted_at).to be_present
        expect(response.status).to eq(200)
      end

      it "won't delete a category topic" do
        c = Fabricate(:category_with_definition)
        cat_post = c.topic.posts.first
        put(
          "/admin/users/#{user.id}/suspend.json",
          params: suspend_params.merge(
            post_action: 'delete',
            post_id: cat_post.id
          )
        )
        cat_post.reload
        expect(cat_post.deleted_at).to be_blank
        expect(response.status).to eq(200)
      end

      it "won't delete a category topic by replies" do
        c = Fabricate(:category_with_definition)
        cat_post = c.topic.posts.first
        put(
          "/admin/users/#{user.id}/suspend.json",
          params: suspend_params.merge(
            post_action: 'delete_replies',
            post_id: cat_post.id
          )
        )
        cat_post.reload
        expect(cat_post.deleted_at).to be_blank
        expect(response.status).to eq(200)
      end

      it "can delete an associated post and its replies" do
        reply = PostCreator.create(
          Fabricate(:user),
          raw: 'this is the reply text',
          reply_to_post_number: post.post_number,
          topic_id: post.topic_id
        )
        nested_reply = PostCreator.create(
          Fabricate(:user),
          raw: 'this is the reply text2',
          reply_to_post_number: reply.post_number,
          topic_id: post.topic_id
        )
        put "/admin/users/#{user.id}/suspend.json", params: suspend_params.merge(post_action: 'delete_replies')
        expect(post.reload.deleted_at).to be_present
        expect(reply.reload.deleted_at).to be_present
        expect(nested_reply.reload.deleted_at).to be_present
        expect(response.status).to eq(200)
      end

      it "can edit an associated post" do
        put "/admin/users/#{user.id}/suspend.json", params: suspend_params.merge(
          post_action: 'edit',
          post_edit: 'this is the edited content'
        )

        expect(response.status).to eq(200)
        post.reload
        expect(post.deleted_at).to be_blank
        expect(post.raw).to eq("this is the edited content")
        expect(response.status).to eq(200)
      end
    end

    it "can send a message to the user" do
      put "/admin/users/#{user.id}/suspend.json", params: {
        suspend_until: 10.days.from_now,
        reason: "short reason",
        message: "long reason"
      }

      expect(response.status).to eq(200)

      expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      job_args = Jobs::CriticalUserEmail.jobs.first["args"].first
      expect(job_args["type"]).to eq("account_suspended")
      expect(job_args["user_id"]).to eq(user.id)

      log = UserHistory.where(target_user_id: user.id).order('id desc').first
      expect(log).to be_present
      expect(log.details).to match(/short reason/)
      expect(log.details).to match(/long reason/)
    end

    it "also revokes any api keys" do
      Fabricate(:api_key, user: user)
      put "/admin/users/#{user.id}/suspend.json", params: suspend_params

      expect(response.status).to eq(200)
      user.reload

      expect(user).to be_suspended
      expect(ApiKey.where(user_id: user.id).count).to eq(0)
    end
  end

  describe '#revoke_admin' do
    fab!(:another_admin) { Fabricate(:admin) }

    it 'raises an error unless the user can revoke access' do
      sign_in(user)
      put "/admin/users/#{another_admin.id}/revoke_admin.json"
      expect(response.status).to eq(404)
      another_admin.reload
      expect(another_admin.admin).to eq(true)
    end

    it 'updates the admin flag' do
      put "/admin/users/#{another_admin.id}/revoke_admin.json"
      expect(response.status).to eq(200)
      another_admin.reload
      expect(another_admin.admin).to eq(false)
    end
  end

  describe '#grant_admin' do
    fab!(:another_user) { Fabricate(:coding_horror) }

    after do
      $redis.flushall
    end

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{another_user.id}/grant_admin.json"
      expect(response.status).to eq(404)
      expect(AdminConfirmation.exists_for?(another_user.id)).to eq(false)
    end

    it "returns a 404 if the username doesn't exist" do
      put "/admin/users/123123/grant_admin.json"
      expect(response.status).to eq(404)
    end

    it 'updates the admin flag' do
      expect(AdminConfirmation.exists_for?(another_user.id)).to eq(false)
      put "/admin/users/#{another_user.id}/grant_admin.json"
      expect(response.status).to eq(200)
      expect(AdminConfirmation.exists_for?(another_user.id)).to eq(true)
    end
  end

  describe '#add_group' do
    fab!(:group) { Fabricate(:group) }

    it 'adds the user to the group' do
      post "/admin/users/#{user.id}/groups.json", params: {
        group_id: group.id
      }

      expect(response.status).to eq(200)
      expect(GroupUser.where(user_id: user.id, group_id: group.id).exists?).to eq(true)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
      expect(group_history.acting_user).to eq(admin)
      expect(group_history.target_user).to eq(user)

      # Doing it again doesn't raise an error
      post "/admin/users/#{user.id}/groups.json", params: {
        group_id: group.id
      }

      expect(response.status).to eq(200)
    end
  end

  describe '#remove_group' do
    it "also clears the user's primary group" do
      g = Fabricate(:group)
      u = Fabricate(:user, primary_group: g)
      delete "/admin/users/#{u.id}/groups/#{g.id}.json"

      expect(response.status).to eq(200)
      expect(u.reload.primary_group).to eq(nil)
    end
  end

  describe '#trust_level' do
    fab!(:another_user) { Fabricate(:coding_horror, created_at: 1.month.ago) }

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{another_user.id}/trust_level.json"
      expect(response.status).to eq(404)
    end

    it "returns a 404 if the username doesn't exist" do
      put "/admin/users/123123/trust_level.json"
      expect(response.status).to eq(404)
    end

    it "upgrades the user's trust level" do
      put "/admin/users/#{another_user.id}/trust_level.json", params: { level: 2 }

      expect(response.status).to eq(200)
      another_user.reload
      expect(another_user.trust_level).to eq(2)

      expect(UserHistory.where(
        target_user: another_user,
        acting_user: admin,
        action: UserHistory.actions[:change_trust_level]
      ).count).to eq(1)
    end

    it "raises no error when demoting a user below their current trust level (locks trust level)" do
      stat = another_user.user_stat
      stat.topics_entered = SiteSetting.tl1_requires_topics_entered + 1
      stat.posts_read_count = SiteSetting.tl1_requires_read_posts + 1
      stat.time_read = SiteSetting.tl1_requires_time_spent_mins * 60
      stat.save!
      another_user.update(trust_level: TrustLevel[1])

      put "/admin/users/#{another_user.id}/trust_level.json", params: {
        level: TrustLevel[0]
      }

      expect(response.status).to eq(200)
      another_user.reload
      expect(another_user.trust_level).to eq(TrustLevel[0])
      expect(another_user.manual_locked_trust_level).to eq(TrustLevel[0])
    end
  end

  describe '#grant_moderation' do
    fab!(:another_user) { Fabricate(:coding_horror) }

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{another_user.id}/grant_moderation.json"
      expect(response.status).to eq(404)
    end

    it "returns a 404 if the username doesn't exist" do
      put "/admin/users/123123/grant_moderation.json"
      expect(response.status).to eq(404)
    end

    it 'updates the moderator flag' do
      put "/admin/users/#{another_user.id}/grant_moderation.json"
      expect(response.status).to eq(200)
      another_user.reload
      expect(another_user.moderator).to eq(true)
    end
  end

  describe '#revoke_moderation' do
    fab!(:moderator) { Fabricate(:moderator) }

    it 'raises an error unless the user can revoke access' do
      sign_in(user)
      put "/admin/users/#{moderator.id}/revoke_moderation.json"
      expect(response.status).to eq(404)
      moderator.reload
      expect(moderator.moderator).to eq(true)
    end

    it 'updates the moderator flag' do
      put "/admin/users/#{moderator.id}/revoke_moderation.json"
      expect(response.status).to eq(200)
      moderator.reload
      expect(moderator.moderator).to eq(false)
    end
  end

  describe '#primary_group' do
    fab!(:group) { Fabricate(:group) }
    fab!(:another_user) { Fabricate(:coding_horror) }
    fab!(:another_group) { Fabricate(:group, title: 'New') }

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{another_user.id}/primary_group.json"
      expect(response.status).to eq(404)
      another_user.reload
      expect(another_user.primary_group_id).to eq(nil)
    end

    it "returns a 404 if the user doesn't exist" do
      put "/admin/users/123123/primary_group.json"
      expect(response.status).to eq(404)
    end

    it "changes the user's primary group" do
      group.add(another_user)
      put "/admin/users/#{another_user.id}/primary_group.json", params: {
        primary_group_id: group.id
      }

      expect(response.status).to eq(200)
      another_user.reload
      expect(another_user.primary_group_id).to eq(group.id)
    end

    it "doesn't change primary group if they aren't a member of the group" do
      put "/admin/users/#{another_user.id}/primary_group.json", params: {
        primary_group_id: group.id
      }

      expect(response.status).to eq(200)
      another_user.reload
      expect(another_user.primary_group_id).to eq(nil)
    end

    it "remove user's primary group" do
      group.add(another_user)

      put "/admin/users/#{another_user.id}/primary_group.json", params: {
        primary_group_id: ""
      }

      expect(response.status).to eq(200)
      another_user.reload
      expect(another_user.primary_group_id).to eq(nil)
    end

    it "updates user's title when it matches the previous primary group title" do
      group.update_columns(primary_group: true, title: 'Previous')
      group.add(another_user)
      another_group.add(another_user)

      expect(another_user.reload.title).to eq('Previous')

      put "/admin/users/#{another_user.id}/primary_group.json", params: {
        primary_group_id: another_group.id
      }

      another_user.reload
      expect(response.status).to eq(200)
      expect(another_user.primary_group_id).to eq(another_group.id)
      expect(another_user.title).to eq('New')
    end

    it "doesn't update user's title when it does not match the previous primary group title" do
      another_user.update_columns(title: 'Different')
      group.update_columns(primary_group: true, title: 'Previous')
      another_group.add(another_user)
      group.add(another_user)

      expect(another_user.reload.title).to eq('Different')

      put "/admin/users/#{another_user.id}/primary_group.json", params: {
        primary_group_id: another_group.id
      }

      another_user.reload
      expect(response.status).to eq(200)
      expect(another_user.primary_group_id).to eq(another_group.id)
      expect(another_user.title).to eq('Different')
    end
  end

  describe '#destroy' do
    fab!(:delete_me) { Fabricate(:user) }

    it "returns a 403 if the user doesn't exist" do
      delete "/admin/users/123123drink.json"
      expect(response.status).to eq(403)
    end

    context "user has post" do
      let(:topic) { Fabricate(:topic, user: delete_me) }
      let!(:post) { Fabricate(:post, topic: topic, user: delete_me) }

      it "returns an api response that the user can't be deleted because it has posts" do
        delete "/admin/users/#{delete_me.id}.json"
        expect(response.status).to eq(403)
        json = ::JSON.parse(response.body)
        expect(json['deleted']).to eq(false)
      end

      it "doesn't return an error if delete_posts == true" do
        delete "/admin/users/#{delete_me.id}.json", params: { delete_posts: true }
        expect(response.status).to eq(200)
        expect(Post.where(id: post.id).count).to eq(0)
        expect(Topic.where(id: topic.id).count).to eq(0)
        expect(User.where(id: delete_me.id).count).to eq(0)
      end
    end

    it "deletes the user record" do
      delete "/admin/users/#{delete_me.id}.json"
      expect(response.status).to eq(200)
      expect(User.where(id: delete_me.id).count).to eq(0)
    end
  end

  describe '#activate' do
    fab!(:reg_user) { Fabricate(:inactive_user) }

    it "returns success" do
      put "/admin/users/#{reg_user.id}/activate.json"
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json['success']).to eq("OK")
      reg_user.reload
      expect(reg_user.active).to eq(true)
    end

    it "should confirm email even when the tokens are expired" do
      reg_user.email_tokens.update_all(confirmed: false, expired: true)

      reg_user.reload
      expect(reg_user.email_confirmed?).to eq(false)

      put "/admin/users/#{reg_user.id}/activate.json"
      expect(response.status).to eq(200)

      reg_user.reload
      expect(reg_user.email_confirmed?).to eq(true)
    end
  end

  describe '#log_out' do
    fab!(:reg_user) { Fabricate(:user) }

    it "returns success" do
      post "/admin/users/#{reg_user.id}/log_out.json"
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json['success']).to eq("OK")
    end

    it "returns 404 when user_id does not exist" do
      post "/admin/users/123123drink/log_out.json"
      expect(response.status).to eq(404)
    end
  end

  describe '#silence' do
    fab!(:reg_user) { Fabricate(:user) }

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{reg_user.id}/silence.json"
      expect(response.status).to eq(404)
      reg_user.reload
      expect(reg_user).not_to be_silenced
    end

    it "returns a 404 if the user doesn't exist" do
      put "/admin/users/123123/silence.json"
      expect(response.status).to eq(404)
    end

    it "punishes the user for spamming" do
      put "/admin/users/#{reg_user.id}/silence.json"
      expect(response.status).to eq(200)
      reg_user.reload
      expect(reg_user).to be_silenced
    end

    it "can have an associated post" do
      silence_post = Fabricate(:post, user: reg_user)

      put "/admin/users/#{reg_user.id}/silence.json", params: {
        post_id: silence_post.id,
        post_action: 'edit',
        post_edit: "this is the new contents for the post"
      }
      expect(response.status).to eq(200)

      silence_post.reload
      expect(silence_post.raw).to eq("this is the new contents for the post")

      log = UserHistory.where(
        target_user_id: reg_user.id,
        action: UserHistory.actions[:silence_user]
      ).first
      expect(log).to be_present
      expect(log.post_id).to eq(silence_post.id)

      reg_user.reload
      expect(reg_user).to be_silenced
    end

    it "will set a length of time if provided" do
      future_date = 1.month.from_now.to_date
      put "/admin/users/#{reg_user.id}/silence.json", params: {
        silenced_till: future_date
      }

      expect(response.status).to eq(200)
      reg_user.reload
      expect(reg_user).to be_silenced
      expect(reg_user.silenced_till).to eq(future_date)
    end

    it "will send a message if provided" do
      expect do
        put "/admin/users/#{reg_user.id}/silence.json", params: {
          message: "Email this to the user"
        }
      end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

      expect(response.status).to eq(200)
      reg_user.reload
      expect(reg_user).to be_silenced
    end
  end

  describe '#unsilence' do
    fab!(:reg_user) { Fabricate(:user, silenced_till: 10.years.from_now) }

    it "raises an error when the user doesn't have permission" do
      sign_in(user)
      put "/admin/users/#{reg_user.id}/unsilence.json"
      expect(response.status).to eq(404)
    end

    it "returns a 403 if the user doesn't exist" do
      put "/admin/users/123123/unsilence.json"
      expect(response.status).to eq(404)
    end

    it "unsilences the user" do
      put "/admin/users/#{reg_user.id}/unsilence.json"
      expect(response.status).to eq(200)
      reg_user.reload
      expect(reg_user.silenced?).to eq(false)
      log = UserHistory.where(
        target_user_id: reg_user.id,
        action: UserHistory.actions[:unsilence_user]
      ).first
      expect(log).to be_present
    end
  end

  describe '#ip_info' do
    it "retrieves IP info" do
      ip = "81.2.69.142"

      DiscourseIpInfo.open_db(File.join(Rails.root, 'spec', 'fixtures', 'mmdb'))
      Resolv::DNS.any_instance.stubs(:getname).with(ip).returns("ip-81-2-69-142.example.com")

      get "/admin/users/ip-info.json", params: { ip: ip }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).symbolize_keys).to eq(
        city: "London",
        country: "United Kingdom",
        country_code: "GB",
        hostname: "ip-81-2-69-142.example.com",
        location: "London, England, United Kingdom",
        region: "England",
        latitude: 51.5142,
        longitude: -0.0931,
      )
    end
  end

  describe '#delete_other_accounts_with_same_ip' do
    it "works" do
      user_a = Fabricate(:user, ip_address: "42.42.42.42")
      user_b = Fabricate(:user, ip_address: "42.42.42.42")

      delete "/admin/users/delete-others-with-same-ip.json", params: {
        ip: "42.42.42.42", exclude: -1, order: "trust_level DESC"
      }
      expect(response.status).to eq(200)
      expect(User.where(id: user_a.id).count).to eq(0)
      expect(User.where(id: user_b.id).count).to eq(0)
    end
  end

  describe '#invite_admin' do
    let(:api_key) { Fabricate(:api_key, user: admin, key: SecureRandom.hex) }
    let(:api_params) do
      { api_key: api_key.key, api_username: admin.username }
    end

    it "doesn't work when not via API" do
      post "/admin/users/invite_admin.json", params: {
        name: 'Bill', username: 'bill22', email: 'bill@bill.com'
      }

      expect(response.status).to eq(403)
    end

    it 'should invite admin' do
      expect do
        post "/admin/users/invite_admin.json", params: api_params.merge(
          name: 'Bill', username: 'bill22', email: 'bill@bill.com'
        )
      end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

      expect(response.status).to eq(200)

      u = User.find_by_email('bill@bill.com')
      expect(u.name).to eq("Bill")
      expect(u.username).to eq("bill22")
      expect(u.admin).to eq(true)
      expect(u.active).to eq(true)
      expect(u.approved).to eq(true)
    end

    it "doesn't send the email with send_email falsey" do
      expect do
        post "/admin/users/invite_admin.json", params: api_params.merge(
          name: 'Bill', username: 'bill22', email: 'bill@bill.com', send_email: '0'
        )
      end.to change { Jobs::CriticalUserEmail.jobs.size }.by(0)

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["password_url"]).to be_present
    end
  end

  describe '#sync_sso' do
    let(:sso) { SingleSignOn.new }
    let(:sso_secret) { "sso secret" }

    before do
      SiteSetting.email_editable = false
      SiteSetting.sso_url = "https://www.example.com/sso"
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

      user = DiscourseSingleSignOn.parse(sso.payload).lookup_or_create_user

      sso.name = "Bill"
      sso.username = "Hokli$$!!"
      sso.email = "bob2@bob.com"

      post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
      expect(response.status).to eq(200)

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
      post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
      expect(response.status).to eq(200)

      user = User.find_by_email('dr@claw.com')
      expect(user).to be_present
      expect(user.ip_address).to be_blank
    end

    it 'should return the right message if the record is invalid' do
      sso.email = ""
      sso.name = ""
      sso.external_id = "1"

      post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)["message"]).to include("Primary email can't be blank")
    end

    it 'should return the right message if the signature is invalid' do
      sso.name = "Dr. Claw"
      sso.username = "dr_claw"
      sso.email = "dr@claw.com"
      sso.external_id = "2"

      correct_payload = Rack::Utils.parse_query(sso.payload)
      post "/admin/users/sync_sso.json", params: correct_payload.merge(sig: "someincorrectsignature")
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)["message"]).to include(I18n.t('sso.login_error'))
      expect(JSON.parse(response.body)["message"]).not_to include(correct_payload["sig"])
    end
  end

  describe '#disable_second_factor' do
    let(:second_factor) { user.create_totp(enabled: true) }
    let(:second_factor_backup) { user.generate_backup_codes }

    describe 'as an admin' do
      before do
        sign_in(admin)
        second_factor
        second_factor_backup
        expect(user.reload.user_second_factors.totps.first).to eq(second_factor)
      end

      it 'should able to disable the second factor for another user' do
        expect do
          put "/admin/users/#{user.id}/disable_second_factor.json"
        end.to change { Jobs::CriticalUserEmail.jobs.length }.by(1)

        expect(response.status).to eq(200)
        expect(user.reload.user_second_factors).to be_empty

        job_args = Jobs::CriticalUserEmail.jobs.first["args"].first

        expect(job_args["user_id"]).to eq(user.id)
        expect(job_args["type"]).to eq('account_second_factor_disabled')
      end

      it 'should not be able to disable the second factor for the current user' do
        put "/admin/users/#{admin.id}/disable_second_factor.json"

        expect(response.status).to eq(403)
      end

      describe 'when user does not have second factor enabled' do
        it 'should raise the right error' do
          user.user_second_factors.destroy_all

          put "/admin/users/#{user.id}/disable_second_factor.json"

          expect(response.status).to eq(400)
        end
      end
    end
  end

  describe "#penalty_history" do
    fab!(:moderator) { Fabricate(:moderator) }
    let(:logger) { StaffActionLogger.new(admin) }

    it "doesn't allow moderators to clear a user's history" do
      sign_in(moderator)
      delete "/admin/users/#{user.id}/penalty_history.json"
      expect(response.code).to eq("404")
    end

    def find_logs(action)
      UserHistory.where(target_user_id: user.id, action: UserHistory.actions[action])
    end

    it "allows admins to clear a user's history" do
      logger.log_user_suspend(user, "suspend reason")
      logger.log_user_unsuspend(user)
      logger.log_unsilence_user(user)
      logger.log_silence_user(user)

      sign_in(admin)
      delete "/admin/users/#{user.id}/penalty_history.json"
      expect(response.code).to eq("200")

      expect(find_logs(:suspend_user)).to be_blank
      expect(find_logs(:unsuspend_user)).to be_blank
      expect(find_logs(:silence_user)).to be_blank
      expect(find_logs(:unsilence_user)).to be_blank

      expect(find_logs(:removed_suspend_user)).to be_present
      expect(find_logs(:removed_unsuspend_user)).to be_present
      expect(find_logs(:removed_silence_user)).to be_present
      expect(find_logs(:removed_unsilence_user)).to be_present
    end

  end

  describe "#delete_posts_batch" do
    describe 'when user is is invalid' do
      it 'should return the right response' do
        put "/admin/users/nothing/delete_posts_batch.json"

        expect(response.status).to eq(404)
      end
    end

    context "when there are user posts" do
      before do
        post = Fabricate(:post, user: user)
        Fabricate(:post, topic: post.topic, user: user)
        Fabricate(:post, user: user)
      end

      it 'returns how many posts were deleted' do
        put "/admin/users/#{user.id}/delete_posts_batch.json"
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["posts_deleted"]).to eq(3)
      end
    end

    context "when there are no posts left to be deleted" do
      it "returns correct json" do
        put "/admin/users/#{user.id}/delete_posts_batch.json"
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["posts_deleted"]).to eq(0)
      end
    end
  end

end

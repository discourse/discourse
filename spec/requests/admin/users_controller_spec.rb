# frozen_string_literal: true

require "discourse_ip_info"
require "rotp"

RSpec.describe Admin::UsersController do
  fab!(:admin)
  fab!(:another_admin) { Fabricate(:admin) }
  fab!(:moderator)
  fab!(:user)
  fab!(:coding_horror)

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns success with JSON" do
        get "/admin/users/list.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body).to be_present
      end

      it "returns silence reason when user is silenced" do
        silencer =
          UserSilencer.new(
            user,
            admin,
            message: :too_many_spam_flags,
            reason: "because I said so",
            keep_posts: true,
          )
        silencer.silence

        get "/admin/users/list.json"
        expect(response.status).to eq(200)

        silenced_user = response.parsed_body.find { |u| u["id"] == user.id }
        expect(silenced_user["silence_reason"]).to eq("because I said so")
      end

      context "when showing emails" do
        it "returns email for all the users" do
          get "/admin/users/list.json", params: { show_emails: "true" }
          expect(response.status).to eq(200)
          data = response.parsed_body
          data.each { |user| expect(user["email"]).to be_present }
        end

        it "logs only 1 entry" do
          expect do get "/admin/users/list.json", params: { show_emails: "true" } end.to change {
            UserHistory.where(
              action: UserHistory.actions[:check_email],
              acting_user_id: admin.id,
            ).count
          }.by(1)
          expect(response.status).to eq(200)
        end

        it "can be ordered by emails" do
          get "/admin/users/list.json", params: { show_emails: "true", order: "email" }
          expect(response.status).to eq(200)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns users" do
        get "/admin/users/list.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to be_present
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/users/list.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "with an existing user" do
        it "returns success" do
          get "/admin/users/#{user.id}.json"
          expect(response.status).to eq(200)
        end

        it "includes associated accounts" do
          user.user_associated_accounts.create!(
            provider_name: "pluginauth",
            provider_uid: "pluginauth_uid",
          )

          get "/admin/users/#{user.id}.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["external_ids"].size).to eq(1)
          expect(response.parsed_body["external_ids"]["pluginauth"]).to eq("pluginauth_uid")
        end
      end

      context "with a non-existing user" do
        it "returns 404 error" do
          get "/admin/users/0.json"
          expect(response.status).to eq(404)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns user" do
        get "/admin/users/#{user.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["id"]).to eq(user.id)
      end

      it "includes count of similiar users" do
        Fabricate(:user, ip_address: "88.88.88.88")
        Fabricate(:admin, ip_address: user.ip_address)
        Fabricate(:moderator, ip_address: user.ip_address)
        _similar_user = Fabricate(:user, ip_address: user.ip_address)

        get "/admin/users/#{user.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["similar_users_count"]).to eq(1)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/users/#{user.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#similar_users" do
    before { sign_in(admin) }

    it "includes similar users who aren't admin or mods" do
      Fabricate(:user, ip_address: "88.88.88.88")
      Fabricate(:admin, ip_address: user.ip_address)
      Fabricate(:moderator, ip_address: user.ip_address)
      similar_user = Fabricate(:user, ip_address: user.ip_address)

      get "/admin/users/#{user.id}/similar-users.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |u| u["id"] }).to contain_exactly(similar_user.id)
    end
  end

  describe "#approve" do
    let(:evil_trout) { Fabricate(:evil_trout) }

    before { SiteSetting.must_approve_users = true }

    shared_examples "user approval possible" do
      it "creates a reviewable if one does not exist" do
        evil_trout.update!(active: true)
        expect(ReviewableUser.find_by(target: evil_trout)).to be_blank

        put "/admin/users/#{evil_trout.id}/approve.json"

        expect(response.code).to eq("200")
        expect(ReviewableUser.find_by(target: evil_trout)).to be_present
        expect(evil_trout.reload).to be_approved
      end

      it "calls approve" do
        Jobs.run_immediately!
        evil_trout.activate

        put "/admin/users/#{evil_trout.id}/approve.json"

        expect(response.status).to eq(200)
        evil_trout.reload
        expect(evil_trout.approved).to eq(true)
        expect(
          UserHistory.where(
            action: UserHistory.actions[:approve_user],
            target_user_id: evil_trout.id,
          ).count,
        ).to eq(1)
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "user approval possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user approval possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents user approvals with a 404 response" do
        put "/admin/users/#{evil_trout.id}/approve.json"

        evil_trout.reload

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(evil_trout.approved).to eq(false)
      end
    end
  end

  describe "#approve_bulk" do
    let(:evil_trout) { Fabricate(:evil_trout) }

    before { SiteSetting.must_approve_users = true }

    shared_examples "bulk user approval possible" do
      it "does nothing without users" do
        put "/admin/users/approve-bulk.json"
        evil_trout.reload
        expect(response.status).to eq(200)
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

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "bulk user approval possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "bulk user approval possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents bulk user approvals with a 404 response" do
        put "/admin/users/approve-bulk.json", params: { users: [evil_trout.id] }

        evil_trout.reload
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(evil_trout.approved).to eq(false)
      end
    end
  end

  describe "#suspend" do
    fab!(:created_post) { Fabricate(:post) }
    fab!(:other_user) { Fabricate(:user) }
    let(:suspend_params) do
      { suspend_until: 5.hours.from_now, reason: "because of this post", post_id: created_post.id }
    end

    shared_examples "suspension of active user possible" do
      it "suspends user" do
        expect(user).not_to be_suspended

        expect do
          put "/admin/users/#{user.id}/suspend.json",
              params: {
                suspend_until: 5.hours.from_now,
                reason: "because I said so",
              }
        end.not_to change { Jobs::CriticalUserEmail.jobs.size }

        expect(response.status).to eq(200)

        user.reload
        expect(user).to be_suspended
        expect(user.suspended_at).to be_present
        expect(user.suspended_till).to be_present
        expect(user.suspend_record).to be_present

        log = UserHistory.where(target_user_id: user.id).order("id desc").first
        expect(log.details).to match(/because I said so/)
      end
    end

    shared_examples "suspension of staff users" do
      it "doesn't allow suspending a staff user" do
        put "/admin/users/#{another_admin.id}/suspend.json",
            params: {
              suspend_until: 5.hours.from_now,
              reason: "naughty boy",
            }

        expect(response.status).to eq(403)
        expect(another_admin.reload).not_to be_suspended
      end

      it "doesn't allow suspending a staff user via other_user_ids" do
        put "/admin/users/#{user.id}/suspend.json",
            params: {
              suspend_until: 5.hours.from_now,
              reason: "naughty boy",
              other_user_ids: [another_admin.id],
            }

        expect(response.status).to eq(403)
        expect(user.reload).not_to be_suspended
        expect(another_admin.reload).not_to be_suspended
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "suspension of active user possible"
      include_examples "suspension of staff users"

      it "checks if user is suspended" do
        put "/admin/users/#{user.id}/suspend.json",
            params: {
              suspend_until: 5.hours.from_now,
              reason: "because I said so",
            }

        put "/admin/users/#{user.id}/suspend.json",
            params: {
              suspend_until: 5.hours.from_now,
              reason: "because I said so too",
            }

        expect(response.status).to eq(409)
        expect(response.parsed_body["message"]).to eq(
          I18n.t(
            "user.already_suspended",
            staff: admin.username,
            time_ago:
              AgeWords.time_ago_in_words(
                user.suspend_record.created_at,
                true,
                scope: :"datetime.distance_in_words_verbose",
              ),
          ),
        )
      end

      context "with webhook" do
        fab!(:user_web_hook)

        it "enqueues a user_suspended webhook event" do
          expect do
            put "/admin/users/#{user.id}/suspend.json",
                params: {
                  suspend_until: 5.hours.from_now,
                  reason: "because I said so",
                }
          end.to change { Jobs::EmitWebHookEvent.jobs.size }.by(2)

          user.reload
          job_args =
            Jobs::EmitWebHookEvent.jobs.last["args"].find do |args|
              args["event_name"] == "user_suspended"
            end
          expect(job_args).to be_present
          expect(job_args["id"]).to eq(user.id)
          expect(job_args["payload"]).to eq(WebHook.generate_payload(:user, user))
        end
      end

      it "fails the request if the reason is too long" do
        expect(user).not_to be_suspended
        put "/admin/users/#{user.id}/suspend.json",
            params: {
              reason: "x" * 301,
              suspend_until: 5.hours.from_now,
            }
        expect(response.status).to eq(400)
        user.reload
        expect(user).not_to be_suspended
      end

      it "requires suspend_until and reason" do
        expect(user).not_to be_suspended
        put "/admin/users/#{user.id}/suspend.json", params: {}
        expect(response.status).to eq(400)
        user.reload
        expect(user).not_to be_suspended

        expect(user).not_to be_suspended
        put "/admin/users/#{user.id}/suspend.json", params: { suspend_until: 5.hours.from_now }
        expect(response.status).to eq(400)
        user.reload
        expect(user).not_to be_suspended
      end

      it "fails the request if other_user_ids is too big" do
        another_user = Fabricate(:user)
        other_user_ids = [another_user.id]
        other_user_ids.push(*(1..304).to_a)

        put "/admin/users/#{user.id}/suspend.json",
            params: {
              reason: "because I said so",
              suspend_until: 5.hours.from_now,
              other_user_ids:,
            }

        expect(response.status).to eq(400)

        user.reload
        expect(user).not_to be_suspended

        another_user.reload
        expect(another_user).not_to be_suspended
      end

      context "with an associated post" do
        it "can have an associated post" do
          put "/admin/users/#{user.id}/suspend.json", params: suspend_params

          expect(response.status).to eq(200)

          log = UserHistory.where(target_user_id: user.id).order("id desc").first
          expect(log.post_id).to eq(created_post.id)
        end

        it "can delete an associated post" do
          put "/admin/users/#{user.id}/suspend.json",
              params: suspend_params.merge(post_action: "delete")
          created_post.reload
          expect(created_post.deleted_at).to be_present
          expect(response.status).to eq(200)
        end

        it "won't delete a category topic" do
          c = Fabricate(:category_with_definition)
          cat_post = c.topic.posts.first
          put(
            "/admin/users/#{user.id}/suspend.json",
            params: suspend_params.merge(post_action: "delete", post_id: cat_post.id),
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
            params: suspend_params.merge(post_action: "delete_replies", post_id: cat_post.id),
          )
          cat_post.reload
          expect(cat_post.deleted_at).to be_blank
          expect(response.status).to eq(200)
        end

        it "can delete an associated post and its replies" do
          reply =
            PostCreator.create(
              Fabricate(:user),
              raw: "this is the reply text",
              reply_to_post_number: created_post.post_number,
              topic_id: created_post.topic_id,
            )
          nested_reply =
            PostCreator.create(
              Fabricate(:user),
              raw: "this is the reply text2",
              reply_to_post_number: reply.post_number,
              topic_id: created_post.topic_id,
            )
          put "/admin/users/#{user.id}/suspend.json",
              params: suspend_params.merge(post_action: "delete_replies")
          expect(created_post.reload.deleted_at).to be_present
          expect(reply.reload.deleted_at).to be_present
          expect(nested_reply.reload.deleted_at).to be_present
          expect(response.status).to eq(200)
        end

        it "can edit an associated post" do
          put "/admin/users/#{user.id}/suspend.json",
              params:
                suspend_params.merge(post_action: "edit", post_edit: "this is the edited content")

          expect(response.status).to eq(200)
          created_post.reload
          expect(created_post.deleted_at).to be_blank
          expect(created_post.raw).to eq("this is the edited content")
          expect(response.status).to eq(200)
        end
      end

      it "can send a message to the user" do
        put "/admin/users/#{user.id}/suspend.json",
            params: {
              suspend_until: 10.days.from_now,
              reason: "short reason",
              message: "long reason",
            }

        expect(response.status).to eq(200)

        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        job_args = Jobs::CriticalUserEmail.jobs.first["args"].first
        expect(job_args["type"]).to eq("account_suspended")
        expect(job_args["user_id"]).to eq(user.id)

        log = UserHistory.where(target_user_id: user.id).order("id desc").first
        expect(log).to be_present
        expect(log.details).to match(/short reason/)
        expect(log.details).to match(/long reason/)
      end

      it "also prevents use of any api keys" do
        api_key = Fabricate(:api_key, user: user)
        post "/bookmarks.json",
             params: {
               bookmarkable_id: Fabricate(:post).id,
               bookmarkable_type: "Post",
             },
             headers: {
               HTTP_API_KEY: api_key.key,
             }
        expect(response.status).to eq(200)

        put "/admin/users/#{user.id}/suspend.json", params: suspend_params
        expect(response.status).to eq(200)

        user.reload
        expect(user).to be_suspended

        post "/bookmarks.json",
             params: {
               post_id: Fabricate(:post).id,
             },
             headers: {
               HTTP_API_KEY: api_key.key,
             }
        expect(response.status).to eq(403)
      end

      it "can silence multiple users" do
        put "/admin/users/#{user.id}/suspend.json",
            params: {
              suspend_until: 10.days.from_now,
              reason: "short reason",
              message: "long reason",
              other_user_ids: [other_user.id],
            }
        expect(response.status).to eq(200)
        expect(user.reload).to be_suspended
        expect(other_user.reload).to be_suspended
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "suspension of active user possible"
      include_examples "suspension of staff users"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents user suspensions with a 404 response" do
        expect do
          put "/admin/users/#{user.id}/suspend.json",
              params: {
                suspend_until: 5.hours.from_now,
                reason: "because I said so",
              }
        end.not_to change { Jobs::CriticalUserEmail.jobs.size }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        user.reload
        expect(user).not_to be_suspended
        expect(user.suspended_at).to be_nil
        expect(user.suspended_till).to be_nil
        expect(user.suspend_record).to be_nil
      end
    end
  end

  describe "#unsuspend" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "with webhook" do
        fab!(:user_web_hook)

        it "enqueues a user_unsuspended webhook event" do
          user.update!(suspended_at: DateTime.now, suspended_till: 2.years.from_now)

          expect do put "/admin/users/#{user.id}/unsuspend.json" end.to change {
            Jobs::EmitWebHookEvent.jobs.size
          }.by(1)

          user.reload
          job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
          expect(job_args["id"]).to eq(user.id)
          expect(job_args["payload"]).to eq(WebHook.generate_payload(:user, user))
        end
      end
    end
  end

  describe "#revoke_admin" do
    fab!(:another_admin) { Fabricate(:admin) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates the admin flag" do
        put "/admin/users/#{another_admin.id}/revoke_admin.json"
        expect(response.status).to eq(200)
        another_admin.reload
        expect(another_admin.admin).to eq(false)

        expect(response.parsed_body["can_be_merged"]).to eq(true)
        expect(response.parsed_body["can_be_deleted"]).to eq(true)
        expect(response.parsed_body["can_be_anonymized"]).to eq(true)
        expect(response.parsed_body["can_delete_all_posts"]).to eq(true)
      end
    end

    shared_examples "admin access revocation not allowed" do
      it "prevents revoking admin access with a 404 response" do
        put "/admin/users/#{another_admin.id}/revoke_admin.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        another_admin.reload
        expect(another_admin.admin).to eq(true)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "admin access revocation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "admin access revocation not allowed"
    end
  end

  describe "#grant_admin" do
    fab!(:another_user) { coding_horror }

    after { Discourse.redis.flushdb }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a 404 if the username doesn't exist" do
        put "/admin/users/123123/grant_admin.json"
        expect(response.status).to eq(404)
      end

      it "sends a confirmation email if the acting admin does not have a second factor method enabled" do
        expect(AdminConfirmation.exists_for?(another_user.id)).to eq(false)
        put "/admin/users/#{another_user.id}/grant_admin.json"
        expect(response.status).to eq(200)
        expect(AdminConfirmation.exists_for?(another_user.id)).to eq(true)
      end

      it "asks the acting admin for second factor if it is enabled" do
        Fabricate(:user_second_factor_totp, user: admin)

        put "/admin/users/#{another_user.id}/grant_admin.json", xhr: true

        expect(response.parsed_body["second_factor_challenge_nonce"]).to be_present
        expect(another_user.reload.admin).to eq(false)
      end

      it "grants admin if second factor is correct" do
        user_second_factor = Fabricate(:user_second_factor_totp, user: admin)

        put "/admin/users/#{another_user.id}/grant_admin.json", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        expect(nonce).to be_present
        expect(another_user.reload.admin).to eq(false)

        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
               second_factor_method: UserSecondFactor.methods[:totp],
             }
        res = response.parsed_body
        expect(response.status).to eq(200)
        expect(res["ok"]).to eq(true)
        expect(res["callback_method"]).to eq("PUT")
        expect(res["callback_path"]).to eq("/admin/users/#{another_user.id}/grant_admin.json")
        expect(res["redirect_url"]).to eq(
          "/admin/users/#{another_user.id}/#{another_user.username}",
        )
        expect(another_user.reload.admin).to eq(false)

        put res["callback_path"], params: { second_factor_nonce: nonce }
        expect(response.status).to eq(200)
        expect(another_user.reload.admin).to eq(true)
      end

      it "does not grant admin if second factor auth is not successful" do
        user_second_factor = Fabricate(:user_second_factor_totp, user: admin)

        put "/admin/users/#{another_user.id}/grant_admin.json", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        expect(nonce).to be_present
        expect(another_user.reload.admin).to eq(false)

        token = ROTP::TOTP.new(user_second_factor.data).now.to_i
        token = (token == 999_999 ? token - 1 : token + 1).to_s
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_token: token,
               second_factor_method: UserSecondFactor.methods[:totp],
             }
        expect(response.status).to eq(400)
        expect(another_user.reload.admin).to eq(false)

        put "/admin/users/#{another_user.id}/grant_admin.json",
            params: {
              second_factor_nonce: nonce,
            }
        expect(response.status).to eq(401)
        expect(another_user.reload.admin).to eq(false)
      end

      it "does not grant admin if the acting admin loses permission in the middle of the process" do
        user_second_factor = Fabricate(:user_second_factor_totp, user: admin)

        put "/admin/users/#{another_user.id}/grant_admin.json", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        expect(nonce).to be_present
        expect(another_user.reload.admin).to eq(false)

        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
               second_factor_method: UserSecondFactor.methods[:totp],
             }
        res = response.parsed_body
        expect(response.status).to eq(200)
        expect(res["ok"]).to eq(true)
        expect(res["callback_method"]).to eq("PUT")
        expect(res["callback_path"]).to eq("/admin/users/#{another_user.id}/grant_admin.json")
        expect(res["redirect_url"]).to eq(
          "/admin/users/#{another_user.id}/#{another_user.username}",
        )
        expect(another_user.reload.admin).to eq(false)

        admin.update!(admin: false)
        put res["callback_path"], params: { second_factor_nonce: nonce }
        expect(response.status).to eq(404)
        expect(another_user.reload.admin).to eq(false)
      end

      it "does not accept backup codes" do
        Fabricate(:user_second_factor_totp, user: admin)
        Fabricate(:user_second_factor_backup, user: admin)

        put "/admin/users/#{another_user.id}/grant_admin.json", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        expect(nonce).to be_present
        expect(another_user.reload.admin).to eq(false)

        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_token: "iAmValidBackupCode",
               second_factor_method: UserSecondFactor.methods[:backup_codes],
             }
        expect(response.status).to eq(403)
        expect(another_user.reload.admin).to eq(false)
      end
    end

    shared_examples "admin grants not allowed" do
      context "with 2FA enabled" do
        before { Fabricate(:user_second_factor_totp, user: user) }

        it "prevents granting admin with a 404 response" do
          put "/admin/users/#{another_user.id}/grant_admin.json"

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
          expect(AdminConfirmation.exists_for?(another_user.id)).to eq(false)
        end
      end

      context "with 2FA disabled" do
        it "prevents granting admin with a 404 response" do
          put "/admin/users/#{another_user.id}/grant_admin.json"

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
          expect(AdminConfirmation.exists_for?(another_user.id)).to eq(false)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "admin grants not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "admin grants not allowed"
    end
  end

  describe "#add_group" do
    fab!(:group)

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "adds the user to the group" do
        post "/admin/users/#{user.id}/groups.json", params: { group_id: group.id }

        expect(response.status).to eq(200)
        expect(GroupUser.where(user_id: user.id, group_id: group.id).exists?).to eq(true)

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
        expect(group_history.acting_user).to eq(admin)
        expect(group_history.target_user).to eq(user)

        # Doing it again doesn't raise an error
        post "/admin/users/#{user.id}/groups.json", params: { group_id: group.id }

        expect(response.status).to eq(200)
      end

      it "returns not-found error when there is no group" do
        group.destroy!

        put "/admin/users/#{user.id}/groups.json", params: { group_id: group.id }

        expect(response.status).to eq(404)
      end

      it "does not allow adding users to an automatic group" do
        group.update!(automatic: true)

        expect do
          post "/admin/users/#{user.id}/groups.json", params: { group_id: group.id }
        end.to_not change { group.users.count }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(["You cannot modify an automatic group"])
      end
    end

    shared_examples "adding users to groups not allowed" do
      it "prevents adding user to group with a 404 response" do
        post "/admin/users/#{user.id}/groups.json", params: { group_id: group.id }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(GroupUser.where(user_id: user.id, group_id: group.id).exists?).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "adding users to groups not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "adding users to groups not allowed"
    end
  end

  describe "#remove_group" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "also clears the user's primary group" do
        group = Fabricate(:group, users: [user])
        user.update!(primary_group_id: group.id)
        delete "/admin/users/#{user.id}/groups/#{group.id}.json"

        expect(response.status).to eq(200)
        expect(user.reload.primary_group).to eq(nil)
      end

      it "returns not-found error when there is no group" do
        delete "/admin/users/#{user.id}/groups/9090.json"

        expect(response.status).to eq(404)
      end

      it "does not allow removing owners from an automatic group" do
        group = Fabricate(:group, users: [user], automatic: true)

        delete "/admin/users/#{user.id}/groups/#{group.id}.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(["You cannot modify an automatic group"])
      end
    end

    shared_examples "removing user from groups not allowed" do
      it "prevents removing user from group with a 404 response" do
        group = Fabricate(:group, users: [user])
        user.update!(primary_group_id: group.id)

        delete "/admin/users/#{user.id}/groups/#{group.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(user.reload.primary_group).to eq(group)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "removing user from groups not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "removing user from groups not allowed"
    end
  end

  describe "#trust_level" do
    fab!(:another_user) do
      coding_horror.update!(created_at: 1.month.ago)
      coding_horror
    end

    shared_examples "trust level updates possible" do
      it "returns a 404 if the username doesn't exist" do
        put "/admin/users/123123/trust_level.json"
        expect(response.status).to eq(404)
      end

      it "upgrades the user's trust level" do
        put "/admin/users/#{another_user.id}/trust_level.json", params: { level: 2 }

        expect(response.status).to eq(200)
        another_user.reload
        expect(another_user.trust_level).to eq(2)

        expect(
          UserHistory.where(
            target_user: another_user,
            acting_user: acting_user,
            action: UserHistory.actions[:change_trust_level],
          ).count,
        ).to eq(1)
      end

      it "raises no error when demoting a user below their current trust level (locks trust level)" do
        stat = another_user.user_stat
        stat.topics_entered = SiteSetting.tl1_requires_topics_entered + 1
        stat.posts_read_count = SiteSetting.tl1_requires_read_posts + 1
        stat.time_read = SiteSetting.tl1_requires_time_spent_mins * 60
        stat.save!
        another_user.update(trust_level: TrustLevel[1])

        put "/admin/users/#{another_user.id}/trust_level.json", params: { level: TrustLevel[0] }

        expect(response.status).to eq(200)
        another_user.reload
        expect(another_user.trust_level).to eq(TrustLevel[0])
        expect(another_user.manual_locked_trust_level).to eq(TrustLevel[0])
      end
    end

    context "when logged in as an admin" do
      let(:acting_user) { admin }

      before { sign_in(admin) }

      include_examples "trust level updates possible"
    end

    context "when logged in as a moderator" do
      let(:acting_user) { moderator }

      before { sign_in(moderator) }

      include_examples "trust level updates possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents updates trust level with a 404 response" do
        put "/admin/users/#{another_user.id}/trust_level.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#grant_moderation" do
    fab!(:another_user) { coding_horror }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a 404 if the username doesn't exist" do
        put "/admin/users/123123/grant_moderation.json"
        expect(response.status).to eq(404)
      end

      it "updates the moderator flag" do
        expect_enqueued_with(
          job: :send_system_message,
          args: {
            user_id: another_user.id,
            message_type: "welcome_staff",
            message_options: {
              role: :moderator,
            },
          },
        ) { put "/admin/users/#{another_user.id}/grant_moderation.json" }

        expect(response.status).to eq(200)
        another_user.reload
        expect(another_user.moderator).to eq(true)

        expect(response.parsed_body["can_be_merged"]).to eq(false)
        expect(response.parsed_body["can_be_anonymized"]).to eq(false)
      end
    end

    shared_examples "moderator access grant not allowed" do
      it "prevents granting moderation rights to user with a 404 response" do
        put "/admin/users/#{another_user.id}/grant_moderation.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "moderator access grant not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "moderator access grant not allowed"
    end
  end

  describe "#revoke_moderation" do
    fab!(:another_moderator) { Fabricate(:moderator) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates the moderator flag" do
        put "/admin/users/#{another_moderator.id}/revoke_moderation.json"
        expect(response.status).to eq(200)
        another_moderator.reload
        expect(another_moderator.moderator).to eq(false)

        expect(response.parsed_body["can_be_merged"]).to eq(true)
        expect(response.parsed_body["can_be_anonymized"]).to eq(true)
      end
    end

    shared_examples "moderator access revocation not allowed" do
      it "prevents revocation of moderator access with a 404 response" do
        put "/admin/users/#{another_moderator.id}/revoke_moderation.json"

        another_moderator.reload
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(another_moderator.moderator).to eq(true)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "moderator access revocation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "moderator access revocation not allowed"
    end
  end

  describe "#primary_group" do
    fab!(:group)
    fab!(:another_user) { coding_horror }
    fab!(:another_group) { Fabricate(:group, title: "New") }

    shared_examples "primary group updates possible" do
      it "returns a 404 if the user doesn't exist" do
        put "/admin/users/123123/primary_group.json"
        expect(response.status).to eq(404)
      end

      it "changes the user's primary group" do
        group.add(another_user)
        put "/admin/users/#{another_user.id}/primary_group.json",
            params: {
              primary_group_id: group.id,
            }

        expect(response.status).to eq(200)
        another_user.reload
        expect(another_user.primary_group_id).to eq(group.id)
      end

      it "doesn't change primary group if they aren't a member of the group" do
        put "/admin/users/#{another_user.id}/primary_group.json",
            params: {
              primary_group_id: group.id,
            }

        expect(response.status).to eq(200)
        another_user.reload
        expect(another_user.primary_group_id).to eq(nil)
      end

      it "remove user's primary group" do
        group.add(another_user)

        put "/admin/users/#{another_user.id}/primary_group.json", params: { primary_group_id: "" }

        expect(response.status).to eq(200)
        another_user.reload
        expect(another_user.primary_group_id).to eq(nil)
      end

      it "updates user's title when it matches the previous primary group title" do
        group.update_columns(primary_group: true, title: "Previous")
        group.add(another_user)
        another_group.add(another_user)

        expect(another_user.reload.title).to eq("Previous")

        put "/admin/users/#{another_user.id}/primary_group.json",
            params: {
              primary_group_id: another_group.id,
            }

        another_user.reload
        expect(response.status).to eq(200)
        expect(another_user.primary_group_id).to eq(another_group.id)
        expect(another_user.title).to eq("New")
      end

      it "doesn't update user's title when it does not match the previous primary group title" do
        another_user.update_columns(title: "Different")
        group.update_columns(primary_group: true, title: "Previous")
        another_group.add(another_user)
        group.add(another_user)

        expect(another_user.reload.title).to eq("Different")

        put "/admin/users/#{another_user.id}/primary_group.json",
            params: {
              primary_group_id: another_group.id,
            }

        another_user.reload
        expect(response.status).to eq(200)
        expect(another_user.primary_group_id).to eq(another_group.id)
        expect(another_user.title).to eq("Different")
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "primary group updates possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      context "when moderators_manage_categories_and_groups site setting is enabled" do
        before { SiteSetting.moderators_manage_categories_and_groups = true }

        include_examples "primary group updates possible"
      end

      context "when moderators_manage_categories_and_groups site setting is disabled" do
        before { SiteSetting.moderators_manage_categories_and_groups = false }

        it "prevents setting primary group with a 403 response" do
          group.add(another_user)
          put "/admin/users/#{another_user.id}/primary_group.json",
              params: {
                primary_group_id: group.id,
              }

          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
          another_user.reload
          expect(another_user.primary_group_id).to eq(nil)
        end
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents setting primary group with a 404 response" do
        group.add(another_user)
        put "/admin/users/#{another_user.id}/primary_group.json",
            params: {
              primary_group_id: group.id,
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        another_user.reload
        expect(another_user.primary_group_id).to eq(nil)
      end
    end
  end

  describe "#destroy" do
    fab!(:delete_me) { Fabricate(:user, refresh_auto_groups: true) }

    shared_examples "user deletion possible" do
      it "returns a 403 if the user doesn't exist" do
        delete "/admin/users/123123drink.json"
        expect(response.status).to eq(403)
      end

      context "when user has post" do
        let(:topic) { Fabricate(:topic, user: delete_me) }
        let!(:post) { Fabricate(:post, topic: topic, user: delete_me) }

        it "returns an api response that the user can't be deleted because it has posts" do
          post_count = delete_me.posts.joins(:topic).count
          delete_me_topic = Fabricate(:topic)
          Fabricate(:post, topic: delete_me_topic, user: delete_me)
          PostDestroyer.new(admin, delete_me_topic.first_post, context: "Deleted by admin").destroy

          delete "/admin/users/#{delete_me.id}.json"
          expect(response.status).to eq(403)
          json = response.parsed_body
          expect(json["deleted"]).to eq(false)
          expect(json["message"]).to eq(
            I18n.t("user.cannot_delete_has_posts", username: delete_me.username, count: post_count),
          )
        end

        it "doesn't return an error if delete_posts == true" do
          delete "/admin/users/#{delete_me.id}.json", params: { delete_posts: true }
          expect(response.status).to eq(200)
          expect(Post.where(id: post.id).count).to eq(0)
          expect(Topic.where(id: topic.id).count).to eq(0)
          expect(User.where(id: delete_me.id).count).to eq(0)
        end

        context "when user has reviewable flagged post which was handled" do
          let!(:reviewable) do
            Fabricate(
              :reviewable_flagged_post,
              created_by: admin,
              target_created_by: delete_me,
              target: post,
              topic: topic,
              status: 4,
            )
          end

          it "deletes the user record" do
            delete "/admin/users/#{delete_me.id}.json",
                   params: {
                     delete_posts: true,
                     delete_as_spammer: true,
                   }
            expect(response.status).to eq(200)
            expect(User.where(id: delete_me.id).count).to eq(0)
          end
        end
      end

      it "blocks the e-mail if block_email param is is true" do
        user_emails = delete_me.user_emails.pluck(:email)

        delete "/admin/users/#{delete_me.id}.json", params: { block_email: true }
        expect(response.status).to eq(200)
        expect(ScreenedEmail.exists?(email: user_emails)).to eq(true)
      end

      it "does not block the e-mails if block_email param is is false" do
        user_emails = delete_me.user_emails.pluck(:email)

        delete "/admin/users/#{delete_me.id}.json", params: { block_email: false }
        expect(response.status).to eq(200)
        expect(ScreenedEmail.exists?(email: user_emails)).to eq(false)
      end

      it "does not block the e-mails by default" do
        user_emails = delete_me.user_emails.pluck(:email)

        delete "/admin/users/#{delete_me.id}.json"
        expect(response.status).to eq(200)
        expect(ScreenedEmail.exists?(email: user_emails)).to eq(false)
      end

      it "blocks the ip address if block_ip param is true" do
        ip_address = delete_me.ip_address

        delete "/admin/users/#{delete_me.id}.json", params: { block_ip: true }
        expect(response.status).to eq(200)
        expect(ScreenedIpAddress.exists?(ip_address: ip_address)).to eq(true)
      end

      it "does not block the ip address if block_ip param is false" do
        ip_address = delete_me.ip_address

        delete "/admin/users/#{delete_me.id}.json", params: { block_ip: false }
        expect(response.status).to eq(200)
        expect(ScreenedIpAddress.exists?(ip_address: ip_address)).to eq(false)
      end

      it "does not block the ip address by default" do
        ip_address = delete_me.ip_address

        delete "/admin/users/#{delete_me.id}.json"
        expect(response.status).to eq(200)
        expect(ScreenedIpAddress.exists?(ip_address: ip_address)).to eq(false)
      end

      context "with param block_url" do
        before do
          @post = Fabricate(:post_with_external_links, user: delete_me)
          TopicLink.extract_from(@post)

          @urls =
            TopicLink
              .where(user: delete_me, internal: false)
              .pluck(:url)
              .map { |url| ScreenedUrl.normalize_url(url) }
        end

        it "blocks the urls if block_url param is true" do
          delete "/admin/users/#{delete_me.id}.json",
                 params: {
                   delete_posts: true,
                   block_urls: true,
                 }
          expect(response.status).to eq(200)
          expect(ScreenedUrl.exists?(url: @urls)).to eq(true)
        end

        it "does not block the urls if block_url param is false" do
          delete "/admin/users/#{delete_me.id}.json",
                 params: {
                   delete_posts: true,
                   block_urls: false,
                 }
          expect(response.status).to eq(200)
          expect(ScreenedUrl.exists?(url: @urls)).to eq(false)
        end

        it "does not block the urls by default" do
          delete "/admin/users/#{delete_me.id}.json", params: { delete_posts: true }
          expect(response.status).to eq(200)
          expect(ScreenedUrl.exists?(url: @urls)).to eq(false)
        end
      end

      it "deletes the user record" do
        delete "/admin/users/#{delete_me.id}.json"
        expect(response.status).to eq(200)
        expect(User.where(id: delete_me.id).count).to eq(0)
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "user deletion possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user deletion possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents deleting user with a 404 response" do
        delete "/admin/users/#{delete_me.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(User.where(id: delete_me.id).count).to eq(1)
      end
    end
  end

  describe "#destroy_bulk" do
    fab!(:deleted_users) { Fabricate.times(3, :user) }

    shared_examples "bulk user deletion possible" do
      before { sign_in(current_user) }

      it "can delete multiple users" do
        delete "/admin/users/destroy-bulk.json", params: { user_ids: deleted_users.map(&:id) }
        expect(response.status).to eq(200)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(0)
      end

      it "responds with 404 when sending an empty user_ids list" do
        delete "/admin/users/destroy-bulk.json", params: { user_ids: [] }

        expect(response.status).to eq(404)
      end

      it "doesn't allow deleting a user that can't be deleted" do
        deleted_users[0].update!(admin: true)

        delete "/admin/users/destroy-bulk.json", params: { user_ids: deleted_users.map(&:id) }
        expect(response.status).to eq(403)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(3)
      end

      it "doesn't accept more than 100 user ids" do
        delete "/admin/users/destroy-bulk.json",
               params: {
                 user_ids: deleted_users.map(&:id) + (1..101).to_a,
               }
        expect(response.status).to eq(400)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(3)
      end

      it "doesn't fail when a user id doesn't exist" do
        user_id = (User.unscoped.maximum(:id) || 0) + 1
        delete "/admin/users/destroy-bulk.json",
               params: {
                 user_ids: deleted_users.map(&:id).push(user_id),
               }
        expect(response.status).to eq(200)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(0)
      end

      it "blocks emails and IPs of deleted users if block_ip_and_email is true" do
        current_user.update!(ip_address: IPAddr.new("127.189.34.11"))
        deleted_users[0].update!(ip_address: IPAddr.new("127.189.34.11"))
        deleted_users[1].update!(ip_address: IPAddr.new("249.21.44.3"))
        deleted_users[2].update!(ip_address: IPAddr.new("3.1.22.88"))

        expect do
          delete "/admin/users/destroy-bulk.json",
                 params: {
                   user_ids: deleted_users.map(&:id),
                   block_ip_and_email: true,
                 }
        end.to change {
          ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:block]).count
        }.by(2).and change {
                ScreenedEmail.where(action_type: ScreenedEmail.actions[:block]).count
              }.by(3)

        expect(
          ScreenedIpAddress.exists?(
            ip_address: "249.21.44.3",
            action_type: ScreenedIpAddress.actions[:block],
          ),
        ).to be_truthy
        expect(
          ScreenedIpAddress.exists?(
            ip_address: "3.1.22.88",
            action_type: ScreenedIpAddress.actions[:block],
          ),
        ).to be_truthy
        expect(ScreenedIpAddress.exists?(ip_address: current_user.ip_address)).to be_falsey

        expect(
          ScreenedEmail.exists?(
            email: deleted_users[0].email,
            action_type: ScreenedEmail.actions[:block],
          ),
        ).to be_truthy
        expect(
          ScreenedEmail.exists?(
            email: deleted_users[1].email,
            action_type: ScreenedEmail.actions[:block],
          ),
        ).to be_truthy
        expect(
          ScreenedEmail.exists?(
            email: deleted_users[2].email,
            action_type: ScreenedEmail.actions[:block],
          ),
        ).to be_truthy
        expect(response.status).to eq(200)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(0)
      end

      it "doesn't block emails and IPs of deleted users if block_ip_and_email is false" do
        expect do
          delete "/admin/users/destroy-bulk.json",
                 params: {
                   user_ids: deleted_users.map(&:id),
                   block_ip_and_email: false,
                 }
        end.to not_change {
          ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:block]).count
        }.and not_change { ScreenedEmail.where(action_type: ScreenedEmail.actions[:block]).count }
        expect(response.status).to eq(200)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(0)
      end
    end

    context "when logged in as an admin" do
      include_examples "bulk user deletion possible" do
        let(:current_user) { admin }
      end
    end

    context "when logged in as a moderator" do
      include_examples "bulk user deletion possible" do
        let(:current_user) { moderator }
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "responds with a 404 and doesn't delete users" do
        delete "/admin/users/destroy-bulk.json", params: { user_ids: deleted_users.map(&:id) }
        expect(response.status).to eq(404)
        expect(User.where(id: deleted_users.map(&:id)).count).to eq(3)
      end
    end
  end

  describe "#activate" do
    fab!(:reg_user) { Fabricate(:inactive_user) }

    shared_examples "user activation possible" do
      it "returns success" do
        put "/admin/users/#{reg_user.id}/activate.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["success"]).to eq("OK")
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

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "user activation possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user activation possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents activation of user with a 404 response" do
        put "/admin/users/#{reg_user.id}/activate.json"

        reg_user.reload
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(reg_user.active).to eq(false)
      end
    end
  end

  describe "#deactivate" do
    fab!(:reg_user) { Fabricate(:active_user) }

    shared_examples "user deactivation possible" do
      it "returns success" do
        put "/admin/users/#{reg_user.id}/deactivate.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["success"]).to eq("OK")
        reg_user.reload
        expect(reg_user.active).to eq(false)
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "user deactivation possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user deactivation possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents deactivation of user with a 404 response" do
        put "/admin/users/#{reg_user.id}/deactivate.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        reg_user.reload
        expect(reg_user.active).to eq(true)
      end
    end
  end

  describe "#log_out" do
    fab!(:reg_user) { Fabricate(:user) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns success" do
        post "/admin/users/#{reg_user.id}/log_out.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["success"]).to eq("OK")
      end

      it "returns 404 when user_id does not exist" do
        post "/admin/users/123123drink/log_out.json"
        expect(response.status).to eq(404)
      end
    end

    shared_examples "user log out not allowed" do
      it "prevents logging out of user with a 404 response" do
        post "/admin/users/#{reg_user.id}/log_out.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user log out not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "user log out not allowed"
    end
  end

  describe "#silence" do
    fab!(:reg_user) { Fabricate(:user) }
    fab!(:other_user) { Fabricate(:user) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a 404 if the user doesn't exist" do
        put "/admin/users/123123/silence.json"
        expect(response.status).to eq(404)
      end

      it "doesn't allow silencing another admin" do
        put "/admin/users/#{another_admin.id}/silence.json",
            params: {
              reason: "because reasons",
              silenced_till: 6.hours.from_now,
            }
        expect(response.status).to eq(403)
        expect(another_admin.reload).to_not be_silenced
      end

      it "doesn't allow silencing another admin via other_user_ids" do
        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              other_user_ids: [another_admin.id],
              reason: "because reasons",
              silenced_till: 6.hours.from_now,
            }
        expect(response.status).to eq(403)
        expect(another_admin.reload).to_not be_silenced
        expect(reg_user.reload).to_not be_silenced
      end

      it "punishes the user for spamming" do
        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              reason: "because reasons",
              silenced_till: 7.hours.from_now,
            }
        expect(response.status).to eq(200)
        reg_user.reload
        expect(reg_user).to be_silenced
        expect(reg_user.silenced_record).to be_present
      end

      it "can have an associated post" do
        silence_post = Fabricate(:post, user: reg_user)

        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              reason: "because reasons",
              silenced_till: 7.hours.from_now,
              post_id: silence_post.id,
              post_action: "edit",
              post_edit: "this is the new contents for the post",
            }
        expect(response.status).to eq(200)

        silence_post.reload
        expect(silence_post.raw).to eq("this is the new contents for the post")

        log =
          UserHistory.where(
            target_user_id: reg_user.id,
            action: UserHistory.actions[:silence_user],
          ).first
        expect(log).to be_present
        expect(log.post_id).to eq(silence_post.id)

        reg_user.reload
        expect(reg_user).to be_silenced
      end

      it "will set a length of time if provided" do
        future_date = 1.month.from_now.to_date
        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              reason: "because reasons",
              silenced_till: future_date,
            }

        expect(response.status).to eq(200)
        reg_user.reload
        expect(reg_user).to be_silenced
        expect(reg_user.silenced_till).to eq(future_date)
      end

      it "will send a message if provided" do
        expect do
          put "/admin/users/#{reg_user.id}/silence.json",
              params: {
                reason: "none of your biz",
                silenced_till: 666.hours.from_now,
                message: "Email this to the user",
              }
        end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

        expect(response.status).to eq(200)
        reg_user.reload
        expect(reg_user).to be_silenced
      end

      it "checks if user is silenced" do
        put "/admin/users/#{user.id}/silence.json",
            params: {
              silenced_till: 5.hours.from_now,
              reason: "because I said so",
            }

        put "/admin/users/#{user.id}/silence.json",
            params: {
              silenced_till: 5.hours.from_now,
              reason: "because I said so too",
            }

        expect(response.status).to eq(409)
        expect(response.parsed_body["message"]).to eq(
          I18n.t(
            "user.already_silenced",
            staff: admin.username,
            time_ago:
              AgeWords.time_ago_in_words(
                user.silenced_record.created_at,
                true,
                scope: :"datetime.distance_in_words_verbose",
              ),
          ),
        )
      end

      it "can silence multiple users" do
        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              reason: "because I want to",
              silenced_till: 14.hours.from_now,
              other_user_ids: [other_user.id],
            }
        expect(response.status).to eq(200)
        expect(reg_user.reload).to be_silenced
        expect(other_user.reload).to be_silenced
      end

      it "fails the request if the reason is too long" do
        expect(user).not_to be_silenced
        put "/admin/users/#{user.id}/silence.json",
            params: {
              reason: "x" * 301,
              silenced_till: 5.hours.from_now,
            }
        expect(response.status).to eq(400)
        user.reload
        expect(user).not_to be_suspended
      end

      it "fails the request if other_user_ids is too big" do
        another_user = Fabricate(:user)
        other_user_ids = [another_user.id]
        other_user_ids.push(*(1..304).to_a)

        put "/admin/users/#{user.id}/silence.json",
            params: {
              reason: "because I said so",
              silenced_till: 5.hours.from_now,
              other_user_ids:,
            }

        expect(response.status).to eq(400)

        user.reload
        expect(user).not_to be_silenced

        another_user.reload
        expect(another_user).not_to be_silenced
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "silences user" do
        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              reason: "cuz I wanna",
              silenced_till: 66.hours.from_now,
            }

        expect(response.status).to eq(200)
        reg_user.reload
        expect(reg_user).to be_silenced
        expect(reg_user.silenced_record).to be_present
      end

      it "doesn't allow silencing another admin" do
        put "/admin/users/#{another_admin.id}/silence.json",
            params: {
              reason: "because reasons",
              silenced_till: 3.hours.from_now,
            }
        expect(response.status).to eq(403)
        expect(another_admin.reload).to_not be_silenced
      end

      it "doesn't allow silencing another admin via other_user_ids" do
        put "/admin/users/#{reg_user.id}/silence.json",
            params: {
              other_user_ids: [another_admin.id],
              reason: "because reasons",
              silenced_till: 3.hours.from_now,
            }

        expect(response.status).to eq(403)
        expect(another_admin.reload).to_not be_silenced
        expect(reg_user.reload).to_not be_silenced
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents  silencing user with a 404 response" do
        put "/admin/users/#{reg_user.id}/silence.json"

        reg_user.reload
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(reg_user).not_to be_silenced
      end
    end
  end

  describe "#unsilence" do
    fab!(:reg_user) { Fabricate(:user, silenced_till: 10.years.from_now) }

    shared_examples "unsilencing user possible" do
      it "returns a 403 if the user doesn't exist" do
        put "/admin/users/123123/unsilence.json"
        expect(response.status).to eq(404)
      end

      it "unsilences the user" do
        put "/admin/users/#{reg_user.id}/unsilence.json"
        expect(response.status).to eq(200)
        reg_user.reload
        expect(reg_user.silenced?).to eq(false)
        log =
          UserHistory.where(
            target_user_id: reg_user.id,
            action: UserHistory.actions[:unsilence_user],
          ).first
        expect(log).to be_present
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "unsilencing user possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "unsilencing user possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents unsilencing user with a 404 response" do
        put "/admin/users/#{reg_user.id}/unsilence.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#ip_info" do
    shared_examples "IP info retrieval possible" do
      it "retrieves IP info" do
        ip = "81.2.69.142"

        DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb"))
        Resolv::DNS.any_instance.stubs(:getname).with(ip).returns("ip-81-2-69-142.example.com")

        get "/admin/users/ip-info.json", params: { ip: ip }
        expect(response.status).to eq(200)
        expect(response.parsed_body.symbolize_keys).to eq(
          city: "London",
          country: "United Kingdom",
          country_code: "GB",
          geoname_ids: [6_255_148, 2_635_167, 2_643_743, 6_269_131],
          hostname: "ip-81-2-69-142.example.com",
          location: "London, England, United Kingdom",
          region: "England",
          latitude: 51.5142,
          longitude: -0.0931,
        )
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "IP info retrieval possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "IP info retrieval possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents retrieval of IP info with a 404 response" do
        ip = "81.2.69.142"

        DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb"))
        Resolv::DNS.any_instance.stubs(:getname).with(ip).returns("ip-81-2-69-142.example.com")

        get "/admin/users/ip-info.json", params: { ip: ip }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#delete_other_accounts_with_same_ip" do
    shared_examples "deleting other accounts with same ip possible" do
      it "works" do
        user_a = Fabricate(:user, ip_address: "42.42.42.42")
        user_b = Fabricate(:user, ip_address: "42.42.42.42")

        delete "/admin/users/delete-others-with-same-ip.json",
               params: {
                 ip: "42.42.42.42",
                 exclude: -1,
                 order: "trust_level DESC",
               }
        expect(response.status).to eq(200)
        expect(User.where(id: user_a.id).count).to eq(0)
        expect(User.where(id: user_b.id).count).to eq(0)
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "deleting other accounts with same ip possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "deleting other accounts with same ip possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents deletion of other accounts with same ip with a 404 response" do
        user_a = Fabricate(:user, ip_address: "42.42.42.42")
        user_b = Fabricate(:user, ip_address: "42.42.42.42")

        delete "/admin/users/delete-others-with-same-ip.json",
               params: {
                 ip: "42.42.42.42",
                 exclude: -1,
                 order: "trust_level DESC",
               }
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(User.where(id: user_a.id).count).to eq(1)
        expect(User.where(id: user_b.id).count).to eq(1)
      end
    end
  end

  describe "#sync_sso" do
    let(:sso) { DiscourseConnectBase.new }
    let(:sso_secret) { "sso secret" }

    before do
      SiteSetting.email_editable = false
      SiteSetting.discourse_connect_url = "https://www.example.com/sso"
      SiteSetting.enable_discourse_connect = true
      SiteSetting.auth_overrides_email = true
      SiteSetting.auth_overrides_name = true
      SiteSetting.auth_overrides_username = true
      SiteSetting.discourse_connect_secret = sso_secret
      sso.sso_secret = sso_secret
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "can sync up with the sso" do
        sso.name = "Bob The Bob"
        sso.username = "bob"
        sso.email = "bob@bob.com"
        sso.external_id = "1"

        user =
          DiscourseConnect.parse(
            sso.payload,
            secure_session: read_secure_session,
          ).lookup_or_create_user

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

      it "can sync up with the sso without email" do
        sso.name = "Bob The Bob"
        sso.username = "bob"
        sso.email = "bob@bob.com"
        sso.external_id = "1"

        _user =
          DiscourseConnect.parse(
            sso.payload,
            secure_session: read_secure_session,
          ).lookup_or_create_user

        sso.name = "Bill"
        sso.username = "Hokli$$!!"
        sso.email = nil

        post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
        expect(response.status).to eq(200)
      end

      it "should create new users" do
        sso.name = "Dr. Claw"
        sso.username = "dr_claw"
        sso.email = "dr@claw.com"
        sso.external_id = "2"
        post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
        expect(response.status).to eq(200)

        user = User.find_by_email("dr@claw.com")
        expect(user).to be_present
        expect(user.ip_address).to be_blank
      end

      it "triggers :sync_sso DiscourseEvent" do
        sso.name = "Bob The Bob"
        sso.username = "bob"
        sso.email = "bob@bob.com"
        sso.external_id = "1"

        user =
          DiscourseConnect.parse(
            sso.payload,
            secure_session: read_secure_session,
          ).lookup_or_create_user

        sso.name = "Bill"
        sso.username = "Hokli$$!!"
        sso.email = "bob2@bob.com"

        events =
          DiscourseEvent.track_events do
            post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
          end
        expect(events).to include(event_name: :sync_sso, params: [user])
      end

      it "should return the right message if the record is invalid" do
        sso.email = ""
        sso.name = ""
        sso.external_id = "1"

        post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
        expect(response.status).to eq(403)
        expect(response.parsed_body["message"]).to include("Primary email can't be blank")
      end

      it "should return the right message if the signature is invalid" do
        sso.name = "Dr. Claw"
        sso.username = "dr_claw"
        sso.email = "dr@claw.com"
        sso.external_id = "2"

        correct_payload = Rack::Utils.parse_query(sso.payload)
        post "/admin/users/sync_sso.json",
             params: correct_payload.merge(sig: "someincorrectsignature")
        expect(response.status).to eq(422)
        expect(response.parsed_body["message"]).to include(I18n.t("discourse_connect.login_error"))
        expect(response.parsed_body["message"]).not_to include(correct_payload["sig"])
      end

      it "returns 404 if the external id does not exist" do
        sso.name = "Dr. Claw"
        sso.username = "dr_claw"
        sso.email = "dr@claw.com"
        sso.external_id = ""
        post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)
        expect(response.status).to eq(422)
        expect(response.parsed_body["message"]).to include(
          I18n.t("discourse_connect.blank_id_error"),
        )
      end
    end

    shared_examples "sso sync not allowed" do
      it "prevents sso sync with a 404 response" do
        sso.name = "Bob The Bob"
        sso.username = "bob"
        sso.email = "bob@bob.com"
        sso.external_id = "1"

        user =
          DiscourseConnect.parse(
            sso.payload,
            secure_session: read_secure_session,
          ).lookup_or_create_user

        sso.name = "Bill"
        sso.username = "Hokli$$!!"
        sso.email = "bob2@bob.com"

        post "/admin/users/sync_sso.json", params: Rack::Utils.parse_query(sso.payload)

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        user.reload
        expect(user.email).to eq("bob@bob.com")
        expect(user.name).to eq("Bob The Bob")
        expect(user.username).to eq("bob")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "sso sync not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "sso sync not allowed"
    end
  end

  describe "#disable_second_factor" do
    let(:second_factor) { user.create_totp(enabled: true) }
    let(:second_factor_backup) { user.generate_backup_codes }
    let(:security_key) { Fabricate(:user_security_key, user: user) }

    before do
      second_factor
      second_factor_backup
      security_key
    end

    context "when logged in as an admin" do
      before do
        sign_in(admin)
        expect(user.reload.user_second_factors.totps.first).to eq(second_factor)
      end

      it "should able to disable the second factor for another user" do
        expect do put "/admin/users/#{user.id}/disable_second_factor.json" end.to change {
          Jobs::CriticalUserEmail.jobs.length
        }.by(1)

        expect(response.status).to eq(200)
        expect(user.reload.user_second_factors).to be_empty
        expect(user.reload.security_keys).to be_empty

        job_args = Jobs::CriticalUserEmail.jobs.first["args"].first

        expect(job_args["user_id"]).to eq(user.id)
        expect(job_args["type"]).to eq("account_second_factor_disabled")
      end

      it "should not be able to disable the second factor for the current user" do
        put "/admin/users/#{admin.id}/disable_second_factor.json"

        expect(response.status).to eq(403)
      end

      describe "when user has only one second factor type enabled" do
        it "should succeed with security keys" do
          user.user_second_factors.destroy_all

          put "/admin/users/#{user.id}/disable_second_factor.json"

          expect(response.status).to eq(200)
        end
        it "should succeed with totp" do
          user.security_keys.destroy_all

          put "/admin/users/#{user.id}/disable_second_factor.json"

          expect(response.status).to eq(200)
        end
      end

      describe "when user does not have second factor enabled" do
        it "should raise the right error" do
          user.user_second_factors.destroy_all
          user.security_keys.destroy_all

          put "/admin/users/#{user.id}/disable_second_factor.json"

          expect(response.status).to eq(400)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "prevents disabling the second factor with a 403 response" do
        expect do put "/admin/users/#{user.id}/disable_second_factor.json" end.not_to change {
          Jobs::CriticalUserEmail.jobs.length
        }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))

        expect(user.reload.user_second_factors).not_to be_empty
        expect(user.reload.security_keys).not_to be_empty
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents disabling the second factor with a 403 response" do
        expect do put "/admin/users/#{user.id}/disable_second_factor.json" end.not_to change {
          Jobs::CriticalUserEmail.jobs.length
        }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        expect(user.reload.user_second_factors).not_to be_empty
        expect(user.reload.security_keys).not_to be_empty
      end
    end
  end

  describe "#penalty_history" do
    let(:logger) { StaffActionLogger.new(admin) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      def find_logs(action)
        UserHistory.where(target_user_id: user.id, action: UserHistory.actions[action])
      end

      it "allows admins to clear a user's history" do
        logger.log_user_suspend(user, "suspend reason")
        logger.log_user_unsuspend(user)
        logger.log_unsilence_user(user)
        logger.log_silence_user(user)

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

    shared_examples "penalty history deletion not allowed" do
      it "prevents clearing of a user's penalty history with a 404 response" do
        delete "/admin/users/#{user.id}/penalty_history.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "penalty history deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "penalty history deletion not allowed"
    end
  end

  describe "#delete_posts_batch" do
    shared_examples "post batch deletion possible" do
      context "when user is is invalid" do
        it "should return the right response" do
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

        it "returns how many posts were deleted" do
          put "/admin/users/#{user.id}/delete_posts_batch.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["posts_deleted"]).to eq(3)
        end
      end

      context "when there are no posts left to be deleted" do
        it "returns correct json" do
          put "/admin/users/#{user.id}/delete_posts_batch.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["posts_deleted"]).to eq(0)
        end
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "post batch deletion possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "post batch deletion possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents batch deletion of posts with a 404 response" do
        put "/admin/users/#{user.id}/delete_posts_batch.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(response.parsed_body["posts_deleted"]).to be_nil
      end
    end
  end

  describe "#merge" do
    fab!(:target_user) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:first_post) { Fabricate(:post, topic: topic, user: user) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should merge source user to target user" do
        Jobs.run_immediately!
        post "/admin/users/#{user.id}/merge.json", params: { target_username: target_user.username }

        expect(response.status).to eq(200)
        expect(topic.reload.user_id).to eq(target_user.id)
        expect(first_post.reload.user_id).to eq(target_user.id)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "fails to merge source user to target user with 403 response" do
        Jobs.run_immediately!
        post "/admin/users/#{user.id}/merge.json", params: { target_username: target_user.username }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))

        expect(topic.reload.user_id).to eq(user.id)
        expect(first_post.reload.user_id).to eq(user.id)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents  merging source user to target user with a 404 response" do
        Jobs.run_immediately!
        post "/admin/users/#{user.id}/merge.json", params: { target_username: target_user.username }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        expect(topic.reload.user_id).to eq(user.id)
        expect(first_post.reload.user_id).to eq(user.id)
      end
    end
  end

  describe "#sso_record" do
    fab!(:sso_record) do
      SingleSignOnRecord.create!(
        user_id: user.id,
        external_id: "12345",
        external_email: user.email,
        last_payload: "",
      )
    end

    before do
      SiteSetting.discourse_connect_url = "https://www.example.com/sso"
      SiteSetting.enable_discourse_connect = true
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "deletes the record" do
        delete "/admin/users/#{user.id}/sso_record.json"

        expect(response.status).to eq(200)
        expect(user.single_sign_on_record).to eq(nil)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "prevents deletion of sso record with a 403 response" do
        delete "/admin/users/#{user.id}/sso_record.json"

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
        expect(user.single_sign_on_record).to be_present
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents deletion of sso record with a 404 response" do
        delete "/admin/users/#{user.id}/sso_record.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(user.single_sign_on_record).to be_present
      end
    end
  end

  describe "#delete_associated_accounts" do
    fab!(:user_associated_accounts) do
      UserAssociatedAccount.create!(
        provider_name: "github",
        provider_uid: "123456789",
        user_id: user.id,
        last_used: 1.seconds.ago,
      )
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "deletes the record and logs the deletion" do
        put "/admin/users/#{user.id}/delete_associated_accounts.json"

        expect(response.status).to eq(200)
        expect(user.user_associated_accounts).to eq([])
        expect(UserHistory.last).to have_attributes(
          acting_user_id: admin.id,
          target_user_id: user.id,
          action: UserHistory.actions[:delete_associated_accounts],
        )
        expect(UserHistory.last.previous_value).to include(':uid=>"123456789"')
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "prevents deletion of associated accounts with a 403 response" do
        put "/admin/users/#{user.id}/delete_associated_accounts.json"

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
        expect(user.user_associated_accounts).to be_present
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents deletion of associated accounts with a 404 response" do
        put "/admin/users/#{user.id}/delete_associated_accounts.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(user.user_associated_accounts).to be_present
      end
    end
  end

  describe "#anonymize" do
    shared_examples "user anonymization possible" do
      it "will make the user anonymous" do
        put "/admin/users/#{user.id}/anonymize.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["username"]).to be_present
      end

      it "supports `anonymize_ip`" do
        Jobs.run_immediately!
        sl = Fabricate(:search_log, user_id: user.id)
        put "/admin/users/#{user.id}/anonymize.json?anonymize_ip=127.0.0.2"
        expect(response.status).to eq(200)
        expect(response.parsed_body["username"]).to be_present
        expect(sl.reload.ip_address).to eq("127.0.0.2")
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      include_examples "user anonymization possible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user anonymization possible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents anonymizing user with a 404 response" do
        put "/admin/users/#{user.id}/anonymize.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(response.parsed_body["username"]).to be_nil
      end
    end
  end

  describe "#reset_bounce_score" do
    before { user.user_stat.update!(bounce_score: 10) }

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "will reset the bounce score" do
        post "/admin/users/#{user.id}/reset-bounce-score.json"

        expect(response.status).to eq(200)
        expect(user.reload.user_stat.bounce_score).to eq(0)
        expect(UserHistory.last.action).to eq(UserHistory.actions[:reset_bounce_score])
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "prevents resetting the bounce score with a 404 response" do
        post "/admin/users/#{user.id}/reset-bounce-score.json"

        expect(response.status).to eq(404)
        expect(user.reload.user_stat.bounce_score).to eq(10)
      end
    end
  end
end

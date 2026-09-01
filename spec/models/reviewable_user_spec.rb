# frozen_string_literal: true

RSpec.describe ReviewableUser, type: :model do
  let(:user) do
    user = Fabricate(:user)
    user.activate
    user
  end
  fab!(:admin)
  fab!(:moderator)

  describe "#actions_for" do
    fab!(:reviewable)

    it "returns correct actions in the pending state" do
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(true)
      expect(actions.has?(:delete_user)).to eq(true)
      expect(actions.has?(:delete_user_block)).to eq(true)
      expect(actions.has?(:silence_user)).to eq(false)
      expect(actions.has?(:suspend_user)).to eq(false)
    end

    context "when the user was flagged as a possible spammer" do
      fab!(:reviewable, :suspect_user_reviewable)

      it "returns silence and suspend actions before the delete actions in the confirm-spam bundle" do
        actions = reviewable.actions_for(Guardian.new(moderator))
        bundle = actions.bundles.find { |b| b.id == "#{reviewable.id}-confirm-spam" }

        expect(bundle.actions.map(&:server_action)).to eq(
          %w[silence_user suspend_user delete_user delete_user_block],
        )
      end

      it "doesn't return the silence action when the user is already silenced" do
        reviewable.target.update!(silenced_till: 1.year.from_now)

        actions = reviewable.actions_for(Guardian.new(moderator))
        expect(actions.has?(:silence_user)).to eq(false)
        expect(actions.has?(:suspend_user)).to eq(true)
      end

      it "doesn't return the suspend action when the user is already suspended" do
        reviewable.target.update!(suspended_till: 1.year.from_now, suspended_at: Time.zone.now)

        actions = reviewable.actions_for(Guardian.new(moderator))
        expect(actions.has?(:silence_user)).to eq(true)
        expect(actions.has?(:suspend_user)).to eq(false)
      end

      it "doesn't return silence or suspend actions when the user can't be suspended" do
        reviewable.target.update!(moderator: true)

        actions = reviewable.actions_for(Guardian.new(moderator))
        expect(actions.has?(:silence_user)).to eq(false)
        expect(actions.has?(:suspend_user)).to eq(false)
      end
    end

    context "when the reviewable is rejected" do
      before do
        reviewable.update!(
          status: Reviewable.statuses[:rejected],
          payload: {
            "username" => reviewable.target.username,
          },
        )
      end

      it "doesn't return the scrub action when the payload still matches the user" do
        actions = reviewable.actions_for(Guardian.new(admin))
        expect(actions.has?(:scrub)).to eq(false)
      end

      it "returns the scrub action when the user has been deleted" do
        reviewable.target.destroy!

        actions = reviewable.reload.actions_for(Guardian.new(admin))
        expect(actions.has?(:scrub)).to eq(true)
      end

      it "returns the scrub action when the payload no longer matches the user, like after an anonymization" do
        UserAnonymizer.new(reviewable.target, admin).make_anonymous

        actions = reviewable.reload.actions_for(Guardian.new(admin))
        expect(actions.has?(:scrub)).to eq(true)
      end

      it "doesn't return the scrub action for moderators since the endpoint is admin-only" do
        reviewable.target.destroy!

        actions = reviewable.reload.actions_for(Guardian.new(moderator))
        expect(actions.has?(:scrub)).to eq(false)
      end

      it "doesn't return the scrub action when there is no payload to scrub" do
        reviewable.update!(payload: nil)
        reviewable.target.destroy!

        actions = reviewable.reload.actions_for(Guardian.new(admin))
        expect(actions.has?(:scrub)).to eq(false)
      end
    end

    it "doesn't return anything in the approved state" do
      reviewable.status = Reviewable.statuses[:approved]
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(false)
      expect(actions.has?(:delete_user_block)).to eq(false)
    end

    it "still allows approving in the rejected state" do
      reviewable.status = Reviewable.statuses[:rejected]
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(true)
      expect(actions.has?(:delete_user)).to eq(false)
      expect(actions.has?(:delete_user_block)).to eq(false)
    end

    it "doesn't ask for a rejection reason when deleting a user who was flagged as a possible spammer" do
      reviewable.reviewable_scores.build(user: admin, reason: "suspect_user")

      assert_require_reject_reason(:delete_user, false)
    end

    it "requires a rejection reason to delete a user" do
      assert_require_reject_reason(:delete_user, true)
    end

    it "doesn't ask for a rejection reason when blocking a user who was flagged as a possible spammer" do
      reviewable.reviewable_scores.build(user: admin, reason: "suspect_user")

      assert_require_reject_reason(:delete_user_block, false)
    end

    it "requires a rejection reason to delete and block a user" do
      assert_require_reject_reason(:delete_user_block, true)
    end

    it "doesn't add a confirmation when a rejection reason is already required" do
      action = find_action(:delete_user)

      expect(action.confirm_message).to be_nil
      expect(action.confirm_destructive).to be_nil
    end

    it "asks for confirmation when no rejection reason is required" do
      reviewable.reviewable_scores.build(user: admin, reason: "suspect_user")

      %i[delete_user delete_user_block].each do |id|
        action = find_action(id)

        expect(action.confirm_destructive).to eq(true)
        expect(action.confirm_message_args).to eq(username: reviewable.target.username)
        expect(I18n.t(action.confirm_message, **action.confirm_message_args)).to include(
          "@#{reviewable.target.username}",
        )
      end
    end

    def find_action(id)
      reviewable.actions_for(Guardian.new(moderator)).to_a.find { |a| a.server_action.to_sym == id }
    end

    def assert_require_reject_reason(id, expected)
      expect(find_action(id).require_reject_reason).to eq(expected)
    end
  end

  describe ".payload_for" do
    fab!(:avatar, :upload)

    it "leaves the avatar blank when there is none" do
      payload = ReviewableUser.payload_for(user)

      expect(payload[:avatar_upload_id]).to be_nil
      expect(payload[:avatar_url]).to be_nil
    end

    it "points at the upload rather than the avatar template" do
      user.update!(uploaded_avatar_id: avatar.id)
      user.user_profile.update!(bio_raw: "a bio", website: "https://example.com")

      payload = ReviewableUser.payload_for(user)

      expect(payload).to include(
        username: user.username,
        name: user.name,
        email: user.email,
        bio: "a bio",
        website: "https://example.com",
        avatar_upload_id: avatar.id,
        avatar_url: Discourse.store.cdn_url(avatar.url),
      )
      expect(payload[:avatar_url]).not_to include("user_avatar")
    end
  end

  describe "the avatar snapshot" do
    fab!(:avatar, :upload)
    fab!(:target) { Fabricate(:user, uploaded_avatar_id: avatar.id) }

    it "is referenced on create, so upload cleanup spares it" do
      reviewable =
        ReviewableUser.needs_review!(
          target: target,
          created_by: Discourse.system_user,
          payload: ReviewableUser.payload_for(target),
        )

      expect(UploadReference.exists?(upload_id: avatar.id, target: reviewable)).to eq(true)

      target.remove_avatar!(admin)

      expect(Jobs::CleanUpUploads.new.execute({})).to be_truthy
      expect(Upload.exists?(id: avatar.id)).to eq(true)
    end
  end

  describe "#update_fields" do
    fab!(:reviewable)

    it "doesn't raise errors with an empty update" do
      expect(reviewable.update_fields(nil, moderator)).to eq(true)
      expect(reviewable.update_fields({}, moderator)).to eq(true)
    end
  end

  context "when a user is deleted" do
    it "should reject the reviewable" do
      SiteSetting.must_approve_users = true
      Jobs::CreateUserReviewable.new.execute(user_id: user.id)
      reviewable = Reviewable.find_by(target: user)
      expect(reviewable.pending?).to eq(true)

      UserDestroyer.new(Discourse.system_user).destroy(user)
      expect(reviewable.reload.rejected?).to eq(true)
    end
  end

  describe "#perform" do
    fab!(:reviewable)

    context "when removing an avatar" do
      fab!(:avatar, :upload)

      before do
        reviewable.target.update!(uploaded_avatar_id: avatar.id)
        reviewable.target.user_avatar.update!(custom_upload_id: avatar.id)
      end

      it "resets the avatar and leaves the reviewable pending" do
        result = reviewable.perform(moderator, :remove_avatar)

        expect(result.success?).to eq(true)
        expect(reviewable.reload).to be_pending
        expect(reviewable.target.reload.uploaded_avatar_id).to be_nil
        expect(reviewable.target.user_avatar.reload.custom_upload_id).to be_nil
      end

      it "logs a staff action" do
        expect { reviewable.perform(moderator, :remove_avatar) }.to change {
          UserHistory.where(
            action: UserHistory.actions[:removed_avatar],
            target_user_id: reviewable.target_id,
          ).count
        }.by(1)
      end

      it "leaves the snapshotted image in the payload" do
        reviewable.update!(payload: ReviewableUser.payload_for(reviewable.target))

        reviewable.perform(moderator, :remove_avatar)

        expect(reviewable.reload.payload["avatar_url"]).to be_present
        expect(Upload.exists?(id: avatar.id)).to eq(true)
      end

      it "is offered only while the user still has an avatar" do
        expect(reviewable.actions_for(Guardian.new(moderator)).has?(:remove_avatar)).to eq(true)

        reviewable.target.remove_avatar!(moderator)

        expect(reviewable.actions_for(Guardian.new(moderator)).has?(:remove_avatar)).to eq(false)
      end
    end

    context "when approving" do
      it "allows us to approve a user" do
        result = reviewable.perform(moderator, :approve_user)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.approved?).to eq(true)
        expect(reviewable.target.approved?).to eq(true)
        expect(reviewable.target.approved_by_id).to eq(moderator.id)
        expect(reviewable.target.approved_at).to be_present
        expect(reviewable.version > 0).to eq(true)
      end

      it "logs a staff action linked to the reviewable" do
        expect { reviewable.perform(moderator, :approve_user) }.to change {
          UserHistory.where(
            action: UserHistory.actions[:approve_user],
            reviewable_id: reviewable.id,
          ).count
        }.by(1)
      end

      it "transitions disagreed scores back to agreed when re-approving a rejected reviewable" do
        score =
          reviewable.reviewable_scores.create!(
            user: admin,
            reviewable_score_type: ReviewableScore.types[:needs_approval],
            status: ReviewableScore.statuses[:disagreed],
          )
        reviewable.update!(status: Reviewable.statuses[:rejected])

        reviewable.perform(moderator, :approve_user)

        expect(reviewable.reload).to be_approved
        expect(score.reload.status).to eq("agreed")
      end
    end

    context "when rejecting" do
      it "allows us to reject a user" do
        result = reviewable.perform(moderator, :delete_user, reject_reason: "reject reason")
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
        expect(reviewable.reject_reason).to eq("reject reason")
        expect(UserHistory.last.context).to eq(I18n.t("user.destroy_reasons.reviewable_reject"))
      end

      it "allows us to reject and block a user" do
        email = reviewable.target.email
        ip = reviewable.target.ip_address

        result = reviewable.perform(moderator, :delete_user_block, reject_reason: "reject reason")
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
        expect(reviewable.reject_reason).to eq("reject reason")

        expect(ScreenedEmail.should_block?(email)).to eq(true)
        expect(ScreenedIpAddress.should_block?(ip)).to eq(true)
      end

      it "is not sending email to the user about rejection" do
        SiteSetting.must_approve_users = true
        Jobs::CriticalUserEmail.any_instance.expects(:execute).never
        reviewable.perform(moderator, :delete_user_block, reject_reason: "reject reason")
      end

      it "optionally sends email with reject reason" do
        SiteSetting.must_approve_users = true
        Jobs::CriticalUserEmail
          .any_instance
          .expects(:execute)
          .with(
            {
              type: :signup_after_reject,
              user_id: reviewable.target_id,
              reject_reason: "reject reason",
            },
          )
          .once
        reviewable.perform(
          moderator,
          :delete_user_block,
          reject_reason: "reject reason",
          send_email: true,
        )
      end

      it "allows us to reject a user who has posts" do
        Fabricate(:post, user: reviewable.target)
        result = reviewable.perform(moderator, :delete_user)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_present
        expect(reviewable.target.approved).to eq(false)
      end

      it "allows us to reject a user who has been deleted" do
        reviewable.target.destroy!
        reviewable.reload
        result = reviewable.perform(moderator, :delete_user)
        expect(result.success?).to eq(true)
        expect(reviewable.rejected?).to eq(true)
        expect(reviewable.target).to be_blank
      end

      it "silently transitions the reviewable if the user is an admin" do
        reviewable.target.update!(admin: true)

        result = reviewable.perform(moderator, :delete_user)
        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        reviewable.reload
        expect(reviewable.target).to be_present
        expect(reviewable.target.approved).to eq(false)
      end

      it "logs a staff action linked to the reviewable" do
        expect {
          reviewable.perform(moderator, :delete_user, reject_reason: "reject reason")
        }.to change {
          UserHistory.where(
            action: UserHistory.actions[:delete_user],
            reviewable_id: reviewable.id,
          ).count
        }.by(1)
      end
    end

    context "when suspending or silencing" do
      fab!(:reviewable, :suspect_user_reviewable)

      it "rejects the reviewable and keeps the user, letting the client apply the suspension" do
        result = reviewable.perform(moderator, :suspend_user)
        expect(result.success?).to eq(true)

        expect(reviewable.rejected?).to eq(true)
        expect(reviewable.reload.target).to be_present
        expect(reviewable.target.approved).to eq(false)
        expect(reviewable.target.suspended?).to eq(false)
      end

      it "rejects the reviewable and keeps the user, letting the client apply the silencing" do
        result = reviewable.perform(moderator, :silence_user)
        expect(result.success?).to eq(true)

        expect(reviewable.rejected?).to eq(true)
        expect(reviewable.reload.target).to be_present
        expect(reviewable.target.silenced?).to eq(false)
      end
    end
  end

  describe "changing must_approve_users" do
    it "will approve any existing users" do
      user = Fabricate(:user)
      expect(user).not_to be_approved
      SiteSetting.must_approve_users = true
      expect(user.reload).to be_approved
    end
  end

  describe "when must_approve_users is true" do
    let!(:reviewable) do
      SiteSetting.must_approve_users = true
      Jobs.run_immediately!
      ReviewableUser.find_by(target: user)
    end

    before { Jobs.run_later! }

    it "creates the ReviewableUser for a user, with moderator access" do
      expect(reviewable.reviewable_by_moderator).to eq(true)
    end

    context "with email jobs" do
      it "enqueues a 'signup after approval' email if must_approve_users is true" do
        expect_enqueued_with(job: :critical_user_email, args: { type: :signup_after_approval }) do
          reviewable.perform(admin, :approve_user)
        end
      end

      it "doesn't enqueue a 'signup after approval' email if must_approve_users is false" do
        SiteSetting.must_approve_users = false

        expect_not_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :signup_after_approval,
          },
        ) { reviewable.perform(admin, :approve_user) }
      end
    end

    it "triggers a extensibility event" do
      user && admin # bypass the user_created event
      event =
        DiscourseEvent
          .track_events { ReviewableUser.find_by(target: user).perform(admin, :approve_user) }
          .first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end

    describe "#scrub" do
      it "scrubs the user history record" do
        UserDestroyer.new(admin).destroy(user)
        reviewable.reload

        history = UserHistory.where(action: UserHistory.actions[:delete_user])
        expect(history.count).to eq(1)
        expect(history.first.details).to include("username: #{user.username}")
        expect(history.first.ip_address).not_to be_blank

        reviewable.scrub("reason", Guardian.new(admin))
        reviewable.reload
        history.reload

        expect(history.first.details).to include("User details scrubbed by #{admin.username}")
        expect(history.first.details).to include("reason")
        expect(history.first.details).to include(
          "Timestamp: #{Time.zone.parse(reviewable.payload["scrubbed_at"])}",
        )

        expect(history.first.details).not_to include(user.username)
        expect(history.first.ip_address).to be_blank
      end

      it "doesn't scrub older user history records for the same username" do
        # Create a history record with the same username but older than the reviewable
        UserHistory.create!(
          action: UserHistory.actions[:delete_user],
          details: "id: #{user.id}\nusername: #{user.username}\nname: ",
          created_at: 1.day.ago,
          updated_at: 1.day.ago,
          ip_address: "1.2.3.4",
        )

        UserDestroyer.new(admin).destroy(user)
        reviewable.reload

        history =
          UserHistory.where(action: UserHistory.actions[:delete_user]).order(created_at: :asc)

        expect(history.count).to eq(2)
        expect(history.first.details).to include("username: #{user.username}")
        expect(history.first.ip_address).not_to be_blank
        expect(history.last.details).to include("username: #{user.username}")
        expect(history.last.ip_address).not_to be_blank

        reviewable.scrub("reason", Guardian.new(admin))
        history.reload

        expect(history.first.details).to include(user.username)
        expect(history.first.details).to include("username: #{user.username}")
        expect(history.first.ip_address).not_to be_blank

        expect(history.last.details).to include("User details scrubbed by #{admin.username}")
        expect(history.last.details).to include("reason")
        expect(history.last.details).to include(
          "Timestamp: #{Time.zone.parse(reviewable.payload["scrubbed_at"])}",
        )
        expect(history.last.details).not_to include(user.username)
        expect(history.last.ip_address).to be_blank
      end

      it "replaces the reviewable payload with scrubbed details" do
        expect(reviewable.payload).to be_present
        expect(reviewable.payload["username"]).to eq(user.username)
        expect(reviewable.payload["email"]).to eq(user.email)
        expect(reviewable.payload["name"]).to eq(user.name)

        expect(reviewable.payload["scrubbed_by"]).to be_blank
        expect(reviewable.payload["scrubbed_reason"]).to be_blank
        expect(reviewable.payload["scrubbed_at"]).to be_blank

        reviewable.scrub("reason", Guardian.new(admin))
        reviewable.reload

        expect(reviewable.payload["scrubbed_by"]).to eq(admin.username)
        expect(reviewable.payload["scrubbed_reason"]).to eq("reason")
        expect(reviewable.payload["scrubbed_at"]).to be_present

        expect(reviewable.payload["username"]).to be_blank
        expect(reviewable.payload["email"]).to be_blank
        expect(reviewable.payload["name"]).to be_blank
      end
    end
  end
end

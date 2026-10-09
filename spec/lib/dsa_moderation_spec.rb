# frozen_string_literal: true
RSpec.describe DsaModeration do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:post)

  before { SiteSetting.dsa_reporting_enabled = true }

  describe ".capture" do
    it "retains removal metadata after ordinary post and flagger cleanup" do
      freeze_time
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement).to be_pending
      expect(statement.id).to match(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)
      expect(statement.payload).to include(
        "puid" => statement.id,
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        "content_type" => ["CONTENT_TYPE_TEXT"],
        "content_date" => post.created_at.to_date.iso8601,
        "application_date" => Time.zone.today.iso8601,
        "source_type" => "SOURCE_TYPE_OTHER_NOTIFICATION",
        "automated_detection" => "No",
        "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
      )
      expect(reviewable.reload).to be_approved
      expect(Reviewable.list_for(admin, preload: false).pluck(:id)).not_to include(reviewable.id)
      expect(reviewable.reviewable_notes).to be_empty
      UserDestroyer.new(admin).destroy(flagger)
      post.destroy!
      expect(Reviewable.exists?(reviewable.id)).to eq(false)
      expect(statement.reload.payload["content_date"]).to eq(post.created_at.to_date.iso8601)
      expect(
        statement.payload.keys &
          %w[
            decision_facts
            decision_ground
            category
            incompatible_content_ground
            incompatible_content_explanation
          ],
      ).to be_empty
    end

    it "retains original content and media when staff keep an author deletion" do
      raw = "Personal insults.\n\nhttps://example.test/article"
      cooked = '<p>Personal insults.</p><aside class="onebox"><img src="/image.png"></aside>'
      post.revise(post.user, { raw: raw }, force_new_version: true, skip_validations: true)
      post.update!(cooked: cooked)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      UserSilencer.silence(
        post.user,
        admin,
        keep_posts: true,
        post_id: post.id,
        reason: "Personal attacks",
      )
      PostDestroyer.new(post.user, post).destroy

      reviewable.reload.perform(admin, :agree_and_keep_deleted)
      post.destroy!

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["content_type"]).to contain_exactly(
        "CONTENT_TYPE_TEXT",
        "CONTENT_TYPE_IMAGE",
      )
    end

    it "records each deleted topic item once, including replies from other authors" do
      freeze_time
      reply = Fabricate(:post, topic: post.topic, post_number: 2)
      same_author_reply =
        Fabricate(
          :post,
          topic: post.topic,
          post_number: 3,
          user: post.user,
          created_at: post.created_at,
        )
      Fabricate(:post, topic: post.topic, post_number: 4, post_type: Post.types[:small_action])
      PostActionCreator.like(admin, post)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      statements = DsaStatementOfRecord.where(reviewable_id: reviewable.id)
      expect(statements.pluck(:reviewable_id).uniq).to eq([reviewable.id])
      expect(statements.count).to eq(2)
    end

    it "records only the first handling decision" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.perform(admin, :agree_and_keep)
      reviewable.update!(status: :pending)

      reviewable.perform(admin, :delete_and_agree)

      expect(post.reload).to be_trashed
      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id)).to be_empty
    end

    it "records retaining an existing hidden restriction on the first decision" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      post.hide!(PostActionType.types[:inappropriate])

      reviewable.perform(admin, :agree_and_keep_hidden)

      expect(
        DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id).payload["decision_visibility"],
      ).to eq(["DECISION_VISIBILITY_CONTENT_DISABLED"])
    end

    it "records declined publication without claiming the approval policy detected a violation" do
      queued = Fabricate(:reviewable_queued_post_topic)
      queued.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        reason: :category,
      )

      queued.perform(admin, :reject_post)

      payload = DsaStatementOfRecord.find_by!(reviewable_id: queued.id).payload
      expect(payload).to include(
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        "source_type" => "SOURCE_VOLUNTARY",
        "automated_detection" => "No",
      )
    end

    it "excludes an author withdrawing their own queued submission" do
      queued = Fabricate(:reviewable_queued_post_topic, target_created_by: post.user)

      queued.perform(post.user, :delete)

      expect(queued.reload).to be_deleted
      expect(DsaStatementOfRecord.where(reviewable_id: queued.id)).to be_empty
    end

    it "records an actual user termination and excludes a deletion that fails because posts exist" do
      user = Fabricate(:user, approved: false)
      reviewable = ReviewableUser.create_for(user)
      reviewable.perform(admin, :delete_user)
      expect(
        DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id).payload["decision_account"],
      ).to eq("DECISION_ACCOUNT_TERMINATED")

      existing_author = ReviewableUser.create_for(post.user)
      existing_author.perform(admin, :delete_user)

      expect(User.exists?(post.user_id)).to eq(true)
      expect(DsaStatementOfRecord.where(reviewable_id: existing_author.id)).to be_empty
    end

    it "records a nested queued post rejection when deleting an author as a spammer" do
      queued = Fabricate(:reviewable_queued_post_topic, target_created_by: post.user)
      Fabricate(
        :post,
        user: post.user,
        topic: post.topic,
        post_number: 2,
        post_type: Post.types[:small_action],
        created_at: 3.days.ago,
      )
      reviewable = PostActionCreator.spam(flagger, post).reviewable

      reviewable.perform(admin, :delete_user)

      expect(queued.reload).to be_rejected
      statements = DsaStatementOfRecord.where(reviewable_id: reviewable.id)
      expect(statements.sole.payload["decision_visibility"]).to contain_exactly(
        "DECISION_VISIBILITY_CONTENT_DISABLED",
        "DECISION_VISIBILITY_CONTENT_REMOVED",
      )
      expect(statements.pluck(:reviewable_id).uniq).to eq([reviewable.id])
    end

    it "captures media from the restricted content before removal" do
      post.update!(
        cooked:
          '<p>Text</p><img src="/image.png"><audio src="/audio.mp3"></audio><video src="/video.mp4"></video><iframe src="/embed"></iframe>',
      )
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      payload = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id).payload
      expect(payload["content_type"]).to contain_exactly(
        "CONTENT_TYPE_TEXT",
        "CONTENT_TYPE_IMAGE",
        "CONTENT_TYPE_AUDIO",
        "CONTENT_TYPE_VIDEO",
        "CONTENT_TYPE_OTHER",
      )
      expect(payload["content_type_other"]).to be_present
    end

    it "records a queue lock even when the post was already locked" do
      PostLocker.new(post, admin).lock
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      DsaModeration.capture(reviewable: reviewable, actor: admin, action_name: :lock_post) do
        PostLocker.new(post, admin).lock
      end

      history = UserHistory.where(action: UserHistory.actions[:post_locked], post_id: post.id).last
      expect(history.previous_value).to be_nil
      expect(history.new_value).to be_nil
      expect(
        DsaStatementOfRecord.where(reviewable_id: reviewable.id).sole.payload[
          "decision_visibility"
        ],
      ).to eq(["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"])
    end

    it "excludes unlocking from restriction recording" do
      PostLocker.new(post, admin).lock
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      DsaModeration.capture(reviewable: reviewable, actor: admin, action_name: :unlock_post) do
        PostLocker.new(post, admin).unlock
      end

      expect(post.reload).not_to be_locked
      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id)).to be_empty
    end

    it "leaves reporting inactive by default" do
      SiteSetting.dsa_reporting_enabled = false
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id)).to be_empty
    end
  end

  describe ".record_edit" do
    it "records a linked category edit that restricts access without changing text" do
      category = Fabricate(:private_category, group: Group[:staff])
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reply = Fabricate(:post, topic: post.topic, post_number: 2)

      PostRevisor.new(post, post.topic).revise!(
        admin,
        { category_id: category.id },
        reviewable_id: reviewable.id,
      )

      statements = DsaStatementOfRecord.where(reviewable_id: reviewable.id)
      expect(statements.count).to eq(2)
      expect(statements.map { |statement| statement.payload["decision_visibility"] }.uniq).to eq(
        [["DECISION_VISIBILITY_CONTENT_DISABLED"]],
      )
      expect(flagger.guardian.can_see_post?(post.reload)).to eq(false)
      expect(flagger.guardian.can_see_post?(reply.reload)).to eq(false)
    end

    it "retains removed media when a linked edit also restricts the category" do
      category = Fabricate(:private_category, group: Group[:staff])
      post.update!(cooked: '<p>Original text</p><img src="/image.png">')
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      PostRevisor.new(post, post.topic).revise!(
        admin,
        { raw: "A revised contribution containing only text.", category_id: category.id },
        reviewable_id: reviewable.id,
      )

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["content_type"]).to contain_exactly(
        "CONTENT_TYPE_TEXT",
        "CONTENT_TYPE_IMAGE",
      )
      expect(statement.payload["decision_visibility"]).to contain_exactly(
        "DECISION_VISIBILITY_CONTENT_REMOVED",
        "DECISION_VISIBILITY_CONTENT_DISABLED",
      )
      expect(flagger.guardian.can_see_post?(post.reload)).to eq(false)
    end

    it "retains rendered previews when a linked title edit also restricts the category" do
      category = Fabricate(:private_category, group: Group[:staff])
      post.update!(raw: "Text and https://example.test/article")
      post.update!(cooked: '<p>Text</p><aside class="onebox"><img src="/image.png"></aside>')
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      PostRevisor.new(post, post.topic).revise!(
        admin,
        { title: "A neutral replacement title", category_id: category.id },
        reviewable_id: reviewable.id,
      )

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["content_type"]).to contain_exactly(
        "CONTENT_TYPE_TEXT",
        "CONTENT_TYPE_IMAGE",
      )
      expect(statement.payload["decision_visibility"]).to contain_exactly(
        "DECISION_VISIBILITY_CONTENT_REMOVED",
        "DECISION_VISIBILITY_CONTENT_DISABLED",
      )
      expect(flagger.guardian.can_see_post?(post.reload)).to eq(false)
    end

    it "retains the original media when a queue edit removes an image" do
      post.update!(cooked: '<p>Original text</p><img src="/image.png">')
      original_raw = post.raw
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      PostRevisor.new(post).revise!(
        admin,
        { raw: "A revised contribution containing only text." },
        reviewable_id: reviewable.id,
      )

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["content_type"]).to contain_exactly(
        "CONTENT_TYPE_TEXT",
        "CONTENT_TYPE_IMAGE",
      )
      expect(
        UserHistory
          .where(action: UserHistory.actions[:post_edit], post_id: post.id)
          .sole
          .reviewable_id,
      ).to eq(reviewable.id)
      expect(post.revisions.last.modifications["raw"].first).to eq(original_raw)
    end
  end

  describe ".record_user_history" do
    it "records a later suspension when applied, with its own decision and the original content date" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.perform(admin, :agree_and_suspend)
      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id)).to be_empty

      UserSuspender.new(
        post.user,
        by_user: admin,
        reason: "Personal attacks",
        suspended_till: 1.day.from_now,
        reviewable_id: reviewable.id,
      ).suspend

      statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload).to include(
        "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
        "content_date" => post.created_at.to_date.iso8601,
      )
    end

    it "records replies deleted by a later suspension request" do
      flagged_reply =
        Fabricate(
          :reply,
          user: post.user,
          topic: post.topic,
          reply_to_post_number: post.post_number,
        )
      nested_reply =
        Fabricate(
          :reply,
          user: Fabricate(:user),
          topic: post.topic,
          reply_to_post_number: flagged_reply.post_number,
        )
      flagged_reply.replies << nested_reply
      reviewable = PostActionCreator.inappropriate(flagger, flagged_reply).reviewable
      reviewable.perform(admin, :agree_and_suspend)

      result =
        User::Suspend.call(
          guardian: admin.guardian,
          params: {
            user_id: flagged_reply.user_id,
            reason: "Personal attacks",
            suspend_until: 1.day.from_now,
            post_id: flagged_reply.id,
            post_action: "delete_replies",
            reviewable_id: reviewable.id,
          },
        )

      expect(result).to be_success
      expect(nested_reply.reload).to be_trashed
      expect(
        UserHistory
          .where(action: UserHistory.actions[:delete_post], post_id: nested_reply.id)
          .sole
          .reviewable_id,
      ).to eq(reviewable.id)
      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id).count).to eq(3)
    end

    it "links the suspension dialog restrictions and finite duration to the same reviewable" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.perform(admin, :agree_and_suspend)
      suspend_until = 1.day.from_now

      result =
        User::Suspend.call(
          guardian: admin.guardian,
          params: {
            user_id: post.user_id,
            reason: "Personal attacks",
            suspend_until: suspend_until,
            post_id: post.id,
            post_action: "delete",
            reviewable_id: reviewable.id,
          },
        )

      expect(result).to be_success
      statements = DsaStatementOfRecord.where(reviewable_id: reviewable.id)
      expect(statements.count).to eq(2)
      expect(statements.pluck(:reviewable_id).uniq).to eq([reviewable.id])
      expect(
        statements.where("payload ? 'decision_account'").sole.payload[
          "end_date_account_restriction"
        ],
      ).to eq(suspend_until.to_date.iso8601)
    end

    it "records silence and all posts actually hidden, excluding unrelated direct penalties" do
      post.user.update!(trust_level: TrustLevel[0])
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      UserSilencer.silence(post.user, admin, reviewable_id: reviewable.id)

      statements = DsaStatementOfRecord.where(reviewable_id: reviewable.id)
      expect(
        statements.where("payload ? 'decision_provision'").sole.payload["decision_provision"],
      ).to eq("DECISION_PROVISION_PARTIAL_SUSPENSION")
      expect(
        statements.where("payload ? 'decision_visibility'").sole.payload["decision_visibility"],
      ).to contain_exactly(
        "DECISION_VISIBILITY_CONTENT_DISABLED",
        "DECISION_VISIBILITY_CONTENT_DEMOTED",
      )
      expect { UserSilencer.silence(Fabricate(:user), admin) }.not_to change {
        DsaStatementOfRecord.count
      }
    end
  end

  describe ".with_automated_decision" do
    it "records an AI decision under a staff actor while an ordinary staff API action remains human" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      described_class.with_automated_decision { reviewable.perform(admin, :agree_and_hide) }

      expect(
        DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id).payload["automated_decision"],
      ).to eq("AUTOMATED_DECISION_FULLY")
      second_post = Fabricate(:post)
      reviewable = PostActionCreator.inappropriate(flagger, second_post).reviewable
      reviewable.perform(admin, :delete_and_agree)
      expect(
        DsaStatementOfRecord.where(reviewable_id: reviewable.id).sole.payload["automated_decision"],
      ).to eq("AUTOMATED_DECISION_NOT_AUTOMATED")
    end
  end
end

# frozen_string_literal: true
RSpec.describe DsaModeration do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:post)

  before { SiteSetting.dsa_reporting_enabled = true }

  describe ".capture" do
    it "retains the actual removal and its metadata after the post and reviewable disappear" do
      freeze_time
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      statement = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id)
      expect(statement).to be_pending
      expect(statement.payload).to include(
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        "content_type" => ["CONTENT_TYPE_TEXT"],
        "content_date" => post.created_at.to_date.iso8601,
        "application_date" => Time.zone.today.iso8601,
        "source_type" => "SOURCE_TYPE_OTHER_NOTIFICATION",
        "automated_detection" => "No",
        "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
        "puid" => statement.puid,
      )
      expect(Reviewable.list_for(admin, preload: false).pluck(:id)).to include(reviewable.id)
      reviewable.destroy!
      post.destroy!
      expect(statement.reload.payload["content_date"]).to eq(post.created_at.to_date.iso8601)
    end

    it "records each deleted topic item once, including replies from other authors" do
      reply = Fabricate(:post, topic: post.topic, post_number: 2)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      statements = DsaStatementOfReason.where(reviewable_id: reviewable.id)
      expect(statements.pluck(:target_type, :target_id, :recipient_id)).to contain_exactly(
        ["Post", post.id, post.user_id],
        ["Post", reply.id, reply.user_id],
      )
      expect(statements.pluck(:decision_key).uniq.size).to eq(1)
    end

    it "keeps distinct handling decisions and records a restoration without a new restriction" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.perform(admin, :agree_and_hide)
      first_statement = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id)
      reviewable.update!(status: :pending)

      reviewable.perform(admin, :disagree_and_restore)

      expect(first_statement.reload.reversed_at).to be_present
      expect(DsaStatementOfReason.where(reviewable_id: reviewable.id).count).to eq(1)
      reviewable.update!(status: :pending)
      reviewable.perform(admin, :delete_and_agree)
      expect(
        DsaStatementOfReason.where(reviewable_id: reviewable.id).pluck(:decision_key).uniq.size,
      ).to eq(2)
    end

    it "records a decision to retain hidden content but finishes an unrestricted approval without classification" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.perform(admin, :agree_and_keep)
      expect(DsaStatementOfReason.where(reviewable_id: reviewable.id)).to be_empty
      post.hide!(PostActionType.types[:inappropriate])
      reviewable.update!(status: :pending)

      reviewable.perform(admin, :agree_and_keep_hidden)

      expect(
        DsaStatementOfReason.find_by!(reviewable_id: reviewable.id).payload["decision_visibility"],
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

      payload = DsaStatementOfReason.find_by!(reviewable_id: queued.id).payload
      expect(payload).to include(
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        "source_type" => "SOURCE_VOLUNTARY",
        "automated_detection" => "No",
      )
    end

    it "records an actual user termination and excludes a deletion that fails because posts exist" do
      user = Fabricate(:user, approved: false)
      reviewable = ReviewableUser.create_for(user)
      reviewable.perform(admin, :delete_user)
      expect(
        DsaStatementOfReason.find_by!(reviewable_id: reviewable.id).payload["decision_account"],
      ).to eq("DECISION_ACCOUNT_TERMINATED")

      existing_author = ReviewableUser.create_for(post.user)
      existing_author.perform(admin, :delete_user)

      expect(User.exists?(post.user_id)).to eq(true)
      expect(DsaStatementOfReason.where(reviewable_id: existing_author.id)).to be_empty
    end

    it "captures media from the restricted content before removal" do
      post.update!(
        cooked:
          '<p>Text</p><img src="/image.png"><audio src="/audio.mp3"></audio><video src="/video.mp4"></video><iframe src="/embed"></iframe>',
      )
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      payload = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id).payload
      expect(payload["content_type"]).to contain_exactly(
        "CONTENT_TYPE_TEXT",
        "CONTENT_TYPE_IMAGE",
        "CONTENT_TYPE_AUDIO",
        "CONTENT_TYPE_VIDEO",
        "CONTENT_TYPE_OTHER",
      )
      expect(payload["content_type_other"]).to be_present
    end

    it "leaves reporting inactive by default" do
      SiteSetting.dsa_reporting_enabled = false
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(admin, :delete_and_agree)

      expect(DsaStatementOfReason.where(reviewable_id: reviewable.id)).to be_empty
    end
  end

  describe ".capture_edit" do
    it "retains the original media when a queue edit removes an image" do
      post.update!(cooked: '<p>Original text</p><img src="/image.png">')
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      described_class.capture_edit(reviewable_id: reviewable.id, actor: admin, post: post) do
        PostRevisor.new(post).revise!(
          admin,
          { raw: "A revised contribution containing only text." },
        )
      end

      expect(
        DsaStatementOfReason.find_by!(reviewable_id: reviewable.id).payload["content_type"],
      ).to contain_exactly("CONTENT_TYPE_TEXT", "CONTENT_TYPE_IMAGE")
    end
  end

  describe ".capture_penalty" do
    it "records a later suspension when applied, with its own decision and the original content date" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.perform(admin, :agree_and_suspend)
      expect(DsaStatementOfReason.where(reviewable_id: reviewable.id)).to be_empty

      UserSuspender.new(
        post.user,
        by_user: admin,
        reason: "Personal attacks",
        suspended_till: 1.day.from_now,
        reviewable_id: reviewable.id,
      ).suspend

      statement = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload).to include(
        "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
        "content_date" => post.created_at.to_date.iso8601,
      )
      expect(statement.target_id).to eq(post.user_id)
    end

    it "records silence and all posts actually hidden, excluding unrelated direct penalties" do
      post.user.update!(trust_level: TrustLevel[0])
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      UserSilencer.silence(post.user, admin, reviewable_id: reviewable.id)

      statements = DsaStatementOfReason.where(reviewable_id: reviewable.id)
      expect(statements.where(target_type: "User").sole.payload["decision_provision"]).to eq(
        "DECISION_PROVISION_PARTIAL_SUSPENSION",
      )
      expect(statements.where(target_type: "Post").pluck(:target_id)).to eq([post.id])
      expect { UserSilencer.silence(Fabricate(:user), admin) }.not_to change {
        DsaStatementOfReason.count
      }
    end
  end

  describe ".with_automated_decision" do
    it "records an AI decision under a staff actor while an ordinary staff API action remains human" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      described_class.with_automated_decision { reviewable.perform(admin, :agree_and_hide) }

      expect(
        DsaStatementOfReason.find_by!(reviewable_id: reviewable.id).payload["automated_decision"],
      ).to eq("AUTOMATED_DECISION_FULLY")
      reviewable.update!(status: :pending)
      reviewable.perform(admin, :delete_and_agree)
      expect(
        DsaStatementOfReason.where(reviewable_id: reviewable.id).order(:id).last.payload[
          "automated_decision"
        ],
      ).to eq("AUTOMATED_DECISION_NOT_AUTOMATED")
    end
  end
end

# frozen_string_literal: true

RSpec.describe ReviewablePost do
  fab!(:admin)

  describe "#actions_for" do
    it "requires classification for rejecting or restricting the submitted post" do
      post = Fabricate(:post)
      reviewable = described_class.queue_for_review(post)

      actions = reviewable.actions_for(admin.guardian).to_a

      expect(actions.select(&:dsa_classification_required).map(&:server_action)).to contain_exactly(
        "reject_and_delete",
        "reject_and_suspend",
        "reject_and_silence",
      )
    end
  end

  describe "#build_actions" do
    let(:post) { Fabricate.build(:post) }
    let(:reviewable) { ReviewablePost.new(target: post, target_created_by: post.user) }
    let(:guardian) { Guardian.new }

    it "Does not return available actions when the reviewable is no longer pending" do
      available_actions =
        (Reviewable.statuses.keys - ["pending"]).reduce([]) do |actions, status|
          reviewable.status = status

          actions.concat reviewable_actions(guardian).to_a
        end

      expect(available_actions).to be_empty
    end

    it "only shows the approve post action if users cannot delete the post" do
      expect(reviewable_actions(guardian).has?(:approve)).to eq(true)
      expect(reviewable_actions(guardian).has?(:reject_and_delete)).to eq(false)
    end

    it "includes the reject and delete action if the user is allowed" do
      expect(reviewable_actions(Guardian.new(admin)).has?(:reject_and_delete)).to eq(true)
    end

    it "offers denial and approval for a published reply" do
      SiteSetting.review_queue_consistent_answers = true
      post.post_number = 2

      actions = reviewable_actions(admin.guardian)

      expect(actions.bundles.first.label).to eq("reviewables.actions.deny_post.title")
      expect(
        actions.bundles.first.actions.map { |a| [a.server_action, a.label] },
      ).to contain_exactly(
        %w[reject_and_delete reviewables.actions.deny_and_delete_post.title],
        %w[reject_and_silence reviewables.actions.silence_user.title],
        %w[reject_and_suspend reviewables.actions.suspend_user.title],
      )
      expect(
        actions.bundles.last.actions.map { |action| [action.server_action, action.label] },
      ).to eq([%w[approve reviewables.actions.approve_post.action_title]])
    end

    it "includes the approve post and unhide action if the post is hidden" do
      SiteSetting.review_queue_consistent_answers = true
      post.hidden = true

      actions = reviewable_actions(admin.guardian)

      expect(actions.bundles.last.actions.map(&:label)).to eq(
        ["reviewables.actions.approve_and_unhide.action_title"],
      )
    end

    it "offers a direct delete action to a category moderator" do
      SiteSetting.review_queue_consistent_answers = true
      SiteSetting.enable_category_group_moderation = true
      group_user = Fabricate(:group_user)
      category = Fabricate(:category_moderation_group, group: group_user.group).category
      post = Fabricate(:post, topic: Fabricate(:topic, category:), post_number: 2)
      reviewable = described_class.queue_for_review(post)

      actions = reviewable.actions_for(group_user.user.guardian)

      expect(actions.bundles.first.actions.map(&:label)).to eq(
        ["reviewables.actions.deny_and_delete_post.title"],
      )
    end

    it "includes the reject post and keep deleted action is the post is deleted" do
      post.deleted_at = 1.day.ago

      actions = reviewable_actions(guardian)

      expect(actions.has?(:approve_and_restore)).to eq(false)
      expect(actions.has?(:reject_and_keep_deleted)).to eq(true)
    end

    it "names the restore action when the reviewer can recover a deleted post" do
      SiteSetting.review_queue_consistent_answers = true
      post = Fabricate(:post)
      reviewable = described_class.queue_for_review(post)
      post.trash!(admin)

      actions = reviewable.actions_for(admin.guardian)

      expect(actions.bundles.first.actions.map(&:label)).to include(
        "reviewables.actions.deny_and_keep_deleted.title",
      )
      expect(actions.bundles.last.actions.map(&:label)).to eq(
        ["reviewables.actions.approve_and_restore.action_title"],
      )
    end

    it "doesn't include the suspend action when the author is already suspended" do
      post.user.suspended_till = 1.year.from_now
      post.user.suspended_at = Time.zone.now

      actions = reviewable_actions(Guardian.new(admin))

      expect(actions.has?(:reject_and_suspend)).to eq(false)
      expect(actions.has?(:reject_and_silence)).to eq(true)
    end

    it "doesn't include the silence action when the author is already silenced" do
      post.user.silenced_till = 1.year.from_now

      actions = reviewable_actions(Guardian.new(admin))

      expect(actions.has?(:reject_and_suspend)).to eq(true)
      expect(actions.has?(:reject_and_silence)).to eq(false)
    end

    def reviewable_actions(guardian)
      actions = Reviewable::Actions.new(reviewable, guardian, {})
      reviewable.build_actions(actions, guardian, {})

      actions
    end
  end

  describe "Performing actions" do
    let(:post) { Fabricate(:post) }
    let(:reviewable) { ReviewablePost.needs_review!(target: post, created_by: admin) }

    before { reviewable.created_new! }

    describe "#perform_approve" do
      it "transitions to the approved state" do
        result = reviewable.perform admin, :approve

        expect(result.transition_to).to eq :approved
      end
    end

    describe "#perform_reject_and_suspend" do
      it "rejects the post and suspends its author" do
        result =
          reviewable.perform(
            admin,
            :reject_and_suspend,
            reason: "spam",
            suspend_until: 2.days.from_now,
          )

        expect(result).to be_success
        expect(reviewable.reload).to be_rejected
        expect(post.user.reload).to be_suspended
      end

      it "keeps the post pending when suspension details are invalid" do
        result =
          reviewable.perform(admin, :reject_and_suspend, reason: "", suspend_until: 2.days.from_now)

        expect(result).not_to be_success
        expect(reviewable.reload).to be_pending
        expect(post.user.reload).not_to be_suspended
      end
    end

    describe "#perform_reject_and_silence" do
      it "rejects the post and silences its author" do
        result =
          reviewable.perform(
            admin,
            :reject_and_silence,
            reason: "spam",
            silenced_till: 2.days.from_now,
          )

        expect(result).to be_success
        expect(reviewable.reload).to be_rejected
        expect(post.user.reload).to be_silenced
      end
    end

    describe "#perform_reject_and_keep_deleted" do
      it "transitions to the rejected state and keep the post deleted" do
        post.trash!

        result = reviewable.perform admin, :reject_and_keep_deleted

        expect(result.transition_to).to eq :rejected
        expect(Post.where(id: post.id).exists?).to eq(false)
      end
    end

    describe "#perform_approve_and_restore" do
      it "offers to approve and restore the topic when its first post was deleted with it" do
        SiteSetting.review_queue_consistent_answers = true
        topic = post.topic
        PostDestroyer.new(admin, post).destroy
        actions = reviewable.reload.actions_for(admin.guardian)
        restore = actions.to_a.find { |action| action.server_action == "approve_and_restore" }

        expect(I18n.t(restore.label)).to eq("Approve and restore topic")
        expect(I18n.t(restore.completed_message)).to eq("Topic approved and restored.")
        result = reviewable.perform admin, :approve_and_restore

        expect(result.transition_to).to eq :approved
        expect(Post.where(id: post.id).exists?).to eq(true)
        expect(topic.reload).not_to be_trashed
      end
    end

    describe "#perform_approve_and_unhide" do
      it "transitions to the approved state and unhides the post" do
        post.update!(hidden: true)

        result = reviewable.reload.perform admin, :approve_and_unhide

        expect(result.transition_to).to eq :approved
        expect(post.reload.hidden).to eq(false)
      end

      it "unhides the post as the reviewer" do
        post.update!(hidden: true)

        events =
          DiscourseEvent.track_events(:post_unhidden) do
            reviewable.reload.perform(admin, :approve_and_unhide)
          end

        expect(events.map { |event| event[:params] }).to eq([[post, { acting_user: admin }]])
      end
    end

    describe "#perform_reject_and_delete" do
      it "offers to delete the entire topic when reviewing its first post" do
        SiteSetting.review_queue_consistent_answers = true
        topic = post.topic
        removal =
          reviewable
            .actions_for(admin.guardian)
            .to_a
            .find { |action| action.server_action == "reject_and_delete" }

        expect(I18n.t(removal.label)).to eq("Deny and delete topic")
        expect(I18n.t(removal.completed_message)).to eq("Topic deleted.")

        result = reviewable.perform admin, :reject_and_delete

        expect(result.transition_to).to eq :rejected
        expect(Post.where(id: post.id).exists?).to eq(false)
        expect(topic.reload).to be_trashed
      end
    end
  end

  describe "#perform" do
    context "when the dsa_reporting_enabled site setting is enabled" do
      let(:post) { Fabricate(:post) }
      let(:reviewable) { described_class.needs_review!(target: post, created_by: admin) }

      before do
        freeze_time
        enable_dsa_reporting
      end

      it "creates no statement when approve handles the post reviewable" do
        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when reject_and_delete handles the post reviewable" do
        expect { reviewable.perform(admin, :reject_and_delete) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The post was rejected and removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        )
      end

      it "records a statement when reject_and_keep_deleted handles the post reviewable" do
        post.trash!(admin)

        expect { reviewable.perform(admin, :reject_and_keep_deleted) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The post was rejected and removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        )
      end

      it "creates no statement when approve_and_restore handles the post reviewable" do
        post.trash!(admin)

        expect {
          expect(reviewable.perform(admin, :approve_and_restore)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when approve_and_unhide handles the post reviewable" do
        post.update!(hidden: true)

        expect {
          expect(reviewable.perform(admin, :approve_and_unhide)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "records a statement when reject_and_suspend handles the post reviewable" do
        expect {
          reviewable.perform(
            admin,
            :reject_and_suspend,
            reason: "Spam",
            suspend_until: 2.days.from_now,
          )
        }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The author of the rejected post was suspended.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_date" => post.user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "content_type_other" => "User account",
          "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
          "end_date_account_restriction" => 2.days.from_now.to_date.iso8601,
        )
      end

      it "records a statement when reject_and_silence handles the post reviewable" do
        expect {
          reviewable.perform(
            admin,
            :reject_and_silence,
            reason: "Spam",
            silenced_till: 2.days.from_now,
          )
        }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" =>
            "The author of the rejected post had their ability to participate restricted.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_date" => post.user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "content_type_other" => "User account",
          "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
          "end_date_service_restriction" => 2.days.from_now.to_date.iso8601,
        )
      end
    end
  end
end

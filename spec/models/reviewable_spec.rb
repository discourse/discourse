# frozen_string_literal: true

RSpec.describe Reviewable, type: :model do
  describe "Validations" do
    it { is_expected.to validate_length_of(:reject_reason).is_at_most(2000) }
  end

  describe ".create" do
    fab!(:admin)
    fab!(:user)

    let(:reviewable) { Fabricate.build(:reviewable, created_by: admin) }

    it { is_expected.to have_many(:reviewable_scores).dependent(:destroy) }
    it { is_expected.to have_many(:reviewable_histories).dependent(:destroy) }

    it "can create a reviewable object" do
      expect(reviewable).to be_present
      expect(reviewable.pending?).to eq(true)
      expect(reviewable.created_by).to eq(admin)

      expect(reviewable.editable_for(Guardian.new(admin))).to be_blank

      expect(reviewable.payload).to be_present
      expect(reviewable.version).to eq(0)
      expect(reviewable.payload["name"]).to eq("bandersnatch")
      expect(reviewable.payload["list"]).to eq([1, 2, 3])
    end

    it "can add a target" do
      reviewable.target = user
      reviewable.save!

      expect(reviewable.target_type).to eq("User")
      expect(reviewable.target_id).to eq(user.id)
      expect(reviewable.target).to eq(user)
    end
  end

  describe ".needs_review!" do
    fab!(:admin)
    fab!(:user)

    it "will return a new reviewable the first them, and re-use the second time" do
      r0 = ReviewableUser.needs_review!(target: user, created_by: admin)
      expect(r0).to be_present

      r0.update_column(:status, Reviewable.statuses[:approved])

      r1 = ReviewableUser.needs_review!(target: user, created_by: admin)
      expect(r1.id).to eq(r0.id)
      expect(r1.pending?).to eq(true)
    end

    it "will add a topic and category from a post" do
      post = Fabricate(:post)
      reviewable = ReviewableFlaggedPost.needs_review!(target: post, created_by: Fabricate(:user))
      expect(reviewable.topic).to eq(post.topic)
      expect(reviewable.category).to eq(post.topic.category)
    end

    it "will update the category if the topic category changes" do
      post = Fabricate(:post)
      moderator = Fabricate(:moderator, refresh_auto_groups: true)
      reviewable = PostActionCreator.spam(moderator, post).reviewable
      expect(reviewable.category).to eq(post.topic.category)
      new_cat = Fabricate(:category)
      PostRevisor.new(post).revise!(moderator, category_id: new_cat.id)
      expect(post.topic.reload.category).to eq(new_cat)
      expect(reviewable.reload.category).to eq(new_cat)
    end

    it "can create multiple objects with a NULL target" do
      r0 =
        ReviewableQueuedPost.needs_review!(
          created_by: admin,
          payload: {
            raw: "hello world I am a post",
          },
        )
      expect(r0).to be_present
      r0.update_column(:status, Reviewable.statuses[:approved])

      r1 =
        ReviewableQueuedPost.needs_review!(
          created_by: admin,
          payload: {
            raw: "another post's contents",
          },
        )

      expect(ReviewableQueuedPost.count).to eq(2)
      expect(r1.id).not_to eq(r0.id)
      expect(r1.pending?).to eq(true)
      expect(r0.pending?).to eq(false)
    end

    it "will create a new reviewable when an existing reviewable exists the same target with different type" do
      r0 = Fabricate(:reviewable_queued_post)
      r0.perform(admin, :approve_post)

      r1 = ReviewableFlaggedPost.needs_review!(created_by: admin, target: r0.target)
      expect(r1.pending?).to eq(true)
    end
  end

  describe ".list_for" do
    fab!(:user)

    it "returns an empty list for nil user" do
      expect(Reviewable.list_for(nil)).to eq([])
    end

    context "with a pending item" do
      fab!(:post)
      let(:reviewable) { Fabricate(:reviewable, target: post) }

      it "works with the reviewable by moderator flag" do
        reviewable.reviewable_by_moderator = true
        reviewable.save!

        expect(Reviewable.list_for(user, status: :pending)).to be_empty
        user.update_column(:moderator, true)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])

        # Admins can review everything
        user.update_columns(moderator: false, admin: true)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])
      end

      it "works with the reviewable by group" do
        SiteSetting.enable_category_group_moderation = true
        group = Fabricate(:group)
        category = Fabricate(:category)
        Fabricate(:category_moderation_group, category:, group:)
        reviewable.category_id = category.id
        reviewable.save!

        expect(Reviewable.list_for(user, status: :pending)).to be_empty
        gu = GroupUser.create!(group_id: group.id, user_id: user.id)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])

        # Admins can review everything
        gu.destroy
        user.update_columns(moderator: false, admin: true)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])
      end

      it "doesn't allow review by group when disabled" do
        SiteSetting.enable_category_group_moderation = false
        group = Fabricate(:group)
        category = Fabricate(:category)
        Fabricate(:category_moderation_group, category:, group:)
        reviewable.category_id = category.id
        reviewable.save!

        GroupUser.create!(group_id: group.id, user_id: user.id)
        expect(Reviewable.list_for(user, status: :pending)).to be_blank
      end

      context "as an admin" do
        before { user.update_columns(moderator: false, admin: true) }

        it "can filter by the target_created_by_id attribute" do
          different_reviewable = Fabricate(:reviewable)
          reviewables =
            Reviewable.list_for(user, username: different_reviewable.target_created_by.username)
          expect(reviewables).to include(different_reviewable)
          reviewables = Reviewable.list_for(user, username: user.username)
          expect(reviewables).not_to include(different_reviewable)
        end

        it "can filter by the created_by_id attribute if there is no target" do
          qp = Fabricate(:reviewable_queued_post)
          reviewables = Reviewable.list_for(user, username: qp.created_by.username)
          expect(reviewables).to include(qp)
          reviewables = Reviewable.list_for(user, username: user.username)
          expect(reviewables).not_to include(qp)
        end

        it "can filter by who reviewed the flag" do
          reviewable = Fabricate(:reviewable_flagged_post)
          admin = Fabricate(:admin)
          reviewable.perform(admin, :ignore_and_do_nothing)

          reviewables = Reviewable.list_for(user, status: :all, reviewed_by: admin.username)

          expect(reviewables).to contain_exactly(reviewable)
        end

        it "Does not filter by status when status parameter is set to all" do
          rejected_reviewable =
            Fabricate(:reviewable, target: post, status: Reviewable.statuses[:rejected])
          reviewables = Reviewable.list_for(user, status: :all)
          expect(reviewables).to match_array [reviewable, rejected_reviewable]
        end

        it "supports sorting" do
          r0 = Fabricate(:reviewable, score: 100, created_at: 3.months.ago)
          r1 = Fabricate(:reviewable, score: 999, created_at: 1.month.ago)

          list = Reviewable.list_for(user, sort_order: "score")
          expect(list[0].id).to eq(r1.id)
          expect(list[1].id).to eq(r0.id)

          list = Reviewable.list_for(user, sort_order: "score_asc")
          expect(list[0].id).to eq(r0.id)
          expect(list[1].id).to eq(r1.id)

          list = Reviewable.list_for(user, sort_order: "created_at")
          expect(list[0].id).to eq(r1.id)
          expect(list[1].id).to eq(r0.id)

          list = Reviewable.list_for(user, sort_order: "created_at_asc")
          expect(list[0].id).to eq(r0.id)
          expect(list[1].id).to eq(r1.id)
        end

        describe "Including pending queued posts even if they don't pass the minimum priority threshold" do
          before do
            SiteSetting.reviewable_default_visibility = :high
            Reviewable.set_priorities(high: 10)
            @queued_post =
              Fabricate(:reviewable_queued_post, score: 0, target: post, force_review: true)
            @queued_user = Fabricate(:reviewable_user, score: 0, force_review: true)
          end

          it "includes queued posts when searching for pending reviewables" do
            expect(Reviewable.list_for(user)).to contain_exactly(@queued_post, @queued_user)
          end

          it "excludes pending queued posts when applying a different status filter" do
            expect(Reviewable.list_for(user, status: :deleted)).to be_empty
          end

          it "excludes pending queued posts when applying a different type filter" do
            expect(Reviewable.list_for(user, type: ReviewableFlaggedPost.name)).to be_empty
          end
        end
      end
    end

    context "with a category restriction" do
      fab!(:category) { Fabricate(:category, read_restricted: true) }
      let(:topic) { Fabricate(:topic, category: category) }
      let(:post) { Fabricate(:post, topic: topic) }
      fab!(:moderator)
      fab!(:admin)

      it "respects category id on the reviewable" do
        reviewable =
          ReviewableFlaggedPost.needs_review!(
            target: post,
            created_by: Fabricate(:user),
            reviewable_by_moderator: true,
          )
        expect(reviewable.category).to eq(category)
        expect(Reviewable.list_for(moderator)).not_to include(reviewable)
        expect(Reviewable.list_for(admin)).to include(reviewable)

        category.set_permissions(staff: :full)
        category.save

        expect(Reviewable.list_for(moderator)).to include(reviewable)
      end
    end
  end

  describe ".unseen_list_for" do
    fab!(:admin)
    fab!(:moderator)
    fab!(:group)
    fab!(:category)
    fab!(:user) { Fabricate(:user, groups: [group]) }
    fab!(:admin_reviewable) { Fabricate(:reviewable, reviewable_by_moderator: false) }
    fab!(:mod_reviewable) { Fabricate(:reviewable, reviewable_by_moderator: true) }
    fab!(:category_moderation_group) { Fabricate(:category_moderation_group, category:, group:) }
    fab!(:group_reviewable) { Fabricate(:reviewable, reviewable_by_moderator: false, category:) }

    context "for admins" do
      it "returns a list of pending reviewables that haven't been seen by the user" do
        list = Reviewable.unseen_list_for(admin, preload: false)
        expect(list).to contain_exactly(admin_reviewable, mod_reviewable, group_reviewable)
        admin_reviewable.update!(status: Reviewable.statuses[:approved])
        list = Reviewable.unseen_list_for(admin, preload: false)
        expect(list).to contain_exactly(mod_reviewable, group_reviewable)
        admin.update!(last_seen_reviewable_id: group_reviewable.id)
        expect(Reviewable.unseen_list_for(admin, preload: false).empty?).to eq(true)
      end
    end

    context "for moderators" do
      it "returns a list of pending reviewables that haven't been seen by the user" do
        list = Reviewable.unseen_list_for(moderator, preload: false)
        expect(list).to contain_exactly(mod_reviewable)

        group_reviewable.update!(reviewable_by_moderator: true)

        list = Reviewable.unseen_list_for(moderator, preload: false)
        expect(list).to contain_exactly(mod_reviewable, group_reviewable)

        moderator.update!(last_seen_reviewable_id: mod_reviewable.id)

        list = Reviewable.unseen_list_for(moderator, preload: false)
        expect(list).to contain_exactly(group_reviewable)
      end
    end

    context "for group moderators" do
      before { SiteSetting.enable_category_group_moderation = true }

      it "returns a list of pending reviewables that haven't been seen by the user" do
        list = Reviewable.unseen_list_for(user, preload: false)
        expect(list).to contain_exactly(group_reviewable)

        user.update!(last_seen_reviewable_id: group_reviewable.id)

        list = Reviewable.unseen_list_for(user, preload: false)
        expect(list).to be_empty
      end
    end
  end

  it "valid_types returns the appropriate types" do
    expect(Reviewable.valid_type?("ReviewableUser")).to eq(true)
    expect(Reviewable.valid_type?("ReviewableQueuedPost")).to eq(true)
    expect(Reviewable.valid_type?("ReviewableFlaggedPost")).to eq(true)
    expect(Reviewable.valid_type?(nil)).to eq(false)
    expect(Reviewable.valid_type?("")).to eq(false)
    expect(Reviewable.valid_type?("Reviewable")).to eq(false)
    expect(Reviewable.valid_type?("ReviewableDoesntExist")).to eq(false)
    expect(Reviewable.valid_type?("User")).to eq(false)
  end

  describe "events" do
    let!(:moderator) { Fabricate(:moderator) }
    let(:reviewable) { Fabricate(:reviewable) }

    it "triggers events on create, transition_to" do
      event = DiscourseEvent.track(:reviewable_created) { reviewable.save! }
      expect(event).to be_present
      expect(event[:params].first).to eq(reviewable)

      event =
        DiscourseEvent.track(:reviewable_transitioned_to) do
          reviewable.transition_to(:approved, moderator)
        end
      expect(event).to be_present
      expect(event[:params][0]).to eq(:approved)
      expect(event[:params][1]).to eq(reviewable)
    end
  end

  describe "message bus notifications" do
    fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
    let(:post) { Fabricate(:post) }

    it "triggers a notification on create" do
      reviewable = Fabricate(:reviewable_queued_post)
      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
    end

    it "triggers a notification on update" do
      reviewable = PostActionCreator.create(moderator, post, :inappropriate).reviewable
      reviewable.perform(moderator, :disagree)

      expect {
        PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), post)
      }.to change { reviewable.reload.status }.from("rejected").to("pending").and change {
              Jobs::NotifyReviewable.jobs.size
            }.by(1)
    end

    it "triggers a notification on pending -> approve" do
      reviewable = Fabricate(:reviewable_queued_post)

      expect do reviewable.perform(moderator, :approve_post) end.to change {
        Jobs::NotifyReviewable.jobs.size
      }.by(1)

      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
      expect(job["args"].first["updated_reviewable_ids"]).to contain_exactly(reviewable.id)
    end

    it "triggers a notification on pending -> reject" do
      reviewable = Fabricate(:reviewable_queued_post)

      expect do reviewable.perform(moderator, :reject_post) end.to change {
        Jobs::NotifyReviewable.jobs.size
      }.by(1)

      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
      expect(job["args"].first["updated_reviewable_ids"]).to contain_exactly(reviewable.id)
    end

    it "triggers a notification on approve -> reject to update status" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:approved])

      expect { reviewable.perform(moderator, :reject_post) }.to raise_error(
        Reviewable::InvalidAction,
      )
    end

    it "triggers a notification on approve -> edit to update status" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:approved])

      expect { reviewable.perform(moderator, :edit_post) }.to raise_error(Reviewable::InvalidAction)
    end

    it "triggers a notification on reject -> approve to update status" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:rejected])

      expect do reviewable.perform(moderator, :approve_post) end.to change {
        Jobs::NotifyReviewable.jobs.size
      }.by(1)

      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
      expect(job["args"].first["updated_reviewable_ids"]).to contain_exactly(reviewable.id)
    end
  end

  describe "flag_stats" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:post)
    let(:reviewable) { PostActionCreator.spam(user, post).reviewable }

    it "increases flags_agreed when agreed" do
      expect(user.user_stat.flags_agreed).to eq(0)
      reviewable.perform(Discourse.system_user, :agree_and_keep)
      expect(user.user_stat.reload.flags_agreed).to eq(1)
    end

    it "increases flags_disagreed when disagreed" do
      expect(user.user_stat.flags_disagreed).to eq(0)
      reviewable.perform(Discourse.system_user, :disagree)
      expect(user.user_stat.reload.flags_disagreed).to eq(1)
    end

    it "increases flags_ignored when ignored" do
      expect(user.user_stat.flags_ignored).to eq(0)
      reviewable.perform(Discourse.system_user, :ignore_and_do_nothing)
      expect(user.user_stat.reload.flags_ignored).to eq(1)
    end

    it "doesn't increase stats when you flag yourself" do
      expect(user.user_stat.flags_agreed).to eq(0)
      user_post = Fabricate(:post, user: user)
      self_flag = PostActionCreator.spam(user, user_post).reviewable
      self_flag.perform(Discourse.system_user, :agree_and_keep)
      expect(user.user_stat.reload.flags_agreed).to eq(0)
    end
  end

  describe ".score_required_to_hide_post" do
    it "will return the default visibility if it's higher" do
      described_class.set_priorities(low: 40.0, high: 100.0)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:high]
      expect(described_class.score_required_to_hide_post).to eq(40.0)
    end

    it "returns a default if we can't calculated any percentiles" do
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:low]
      expect(described_class.score_required_to_hide_post).to eq(12.5)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:medium]
      expect(described_class.score_required_to_hide_post).to eq(8.33)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:high]
      expect(described_class.score_required_to_hide_post).to eq(4.16)
    end

    it "returns a fraction of the high percentile" do
      described_class.set_priorities(high: 100.0)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:disabled]
      expect(described_class.score_required_to_hide_post.to_f.truncate(2)).to eq(Float::MAX)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:low]
      expect(described_class.score_required_to_hide_post.to_f.truncate(2)).to eq(100.0)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:medium]
      expect(described_class.score_required_to_hide_post.to_f.truncate(2)).to eq(66.66)
      SiteSetting.hide_post_sensitivity = described_class.sensitivities[:high]
      expect(described_class.score_required_to_hide_post.to_f.truncate(2)).to eq(33.33)
    end
  end

  describe ".spam_score_to_silence_new_user" do
    it "returns a default value if we can't calculated any percentiles" do
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:low]
      expect(described_class.spam_score_to_silence_new_user).to eq(7.5)
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:medium]
      expect(described_class.spam_score_to_silence_new_user).to eq(4.99)
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:high]
      expect(described_class.spam_score_to_silence_new_user).to eq(2.49)
    end

    it "returns a fraction of the high percentile" do
      described_class.set_priorities(high: 100.0)
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:disabled]
      expect(described_class.spam_score_to_silence_new_user.to_f).to eq(Float::MAX)
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:low]
      expect(described_class.spam_score_to_silence_new_user.to_f).to eq(60.0)
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:medium]
      expect(described_class.spam_score_to_silence_new_user.to_f).to eq(39.99)
      SiteSetting.silence_new_user_sensitivity = described_class.sensitivities[:high]
      expect(described_class.spam_score_to_silence_new_user.to_f).to eq(19.99)
    end
  end

  describe ".score_to_auto_close_topic" do
    it "returns the default if we can't calculated any percentiles" do
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:low]
      expect(described_class.score_to_auto_close_topic).to eq(31.25)
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:medium]
      expect(described_class.score_to_auto_close_topic).to eq(20.83)
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:high]
      expect(described_class.score_to_auto_close_topic).to eq(10.41)
    end

    it "returns a fraction of the high percentile" do
      described_class.set_priorities(high: 100.0)
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:disabled]
      expect(described_class.score_to_auto_close_topic.to_f.truncate(2)).to eq(Float::MAX)
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:low]
      expect(described_class.score_to_auto_close_topic.to_f.truncate(2)).to eq(250.0)
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:medium]
      expect(described_class.score_to_auto_close_topic.to_f.truncate(2)).to eq(166.66)
      SiteSetting.auto_close_topic_sensitivity = described_class.sensitivities[:high]
      expect(described_class.score_to_auto_close_topic.to_f.truncate(2)).to eq(83.33)
    end
  end

  describe "priorities" do
    it "returns 0 for unknown priorities" do
      expect(Reviewable.min_score_for_priority(:wat)).to eq(0.0)
    end

    it "returns 0 for all by default" do
      expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
      expect(Reviewable.min_score_for_priority(:medium)).to eq(0.0)
      expect(Reviewable.min_score_for_priority(:high)).to eq(0.0)
    end

    it "can be set manually with `set_priorities`" do
      Reviewable.set_priorities(medium: 12.5, high: 123.45)
      expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
      expect(Reviewable.min_score_for_priority(:medium)).to eq(12.5)
      expect(Reviewable.min_score_for_priority(:high)).to eq(123.45)
    end

    it "will return the default priority if none supplied" do
      Reviewable.set_priorities(medium: 12.3, high: 45.6)
      expect(Reviewable.min_score_for_priority).to eq(0.0)
      SiteSetting.reviewable_default_visibility = "medium"
      expect(Reviewable.min_score_for_priority).to eq(12.3)
      SiteSetting.reviewable_default_visibility = "high"
      expect(Reviewable.min_score_for_priority).to eq(45.6)
    end
  end

  describe "custom filters" do
    after { Reviewable.clear_custom_filters! }

    it "correctly add a new filter" do
      Reviewable.add_custom_filter([:assigned_to, Proc.new { |results, value| results }])

      expect(Reviewable.custom_filters.size).to eq(1)
    end

    it "applies the custom filter" do
      admin = Fabricate(:admin)
      first_reviewable = Fabricate(:reviewable)
      second_reviewable = Fabricate(:reviewable)
      custom_filter = [:target_id, Proc.new { |results, value| results.where(target_id: value) }]
      Reviewable.add_custom_filter(custom_filter)

      results =
        Reviewable.list_for(admin, additional_filters: { target_id: first_reviewable.target_id })

      expect(results.size).to eq(1)
      expect(results.first).to eq first_reviewable
    end

    context "when listing for a moderator with a custom filter that joins tables with same named columns" do
      it "should not error" do
        first_reviewable = Fabricate(:reviewable)
        second_reviewable = Fabricate(:reviewable)
        custom_filter = [
          :troublemaker,
          Proc.new do |results, value|
            results
              .joins(<<~SQL)
          INNER JOIN posts p ON p.id = target_id
          INNER JOIN topics t ON t.id = p.topic_id
          INNER JOIN topic_custom_fields tcf ON tcf.topic_id = t.id
          INNER JOIN users u ON u.id = tcf.value::integer
                          SQL
              .where(target_type: Post.name)
              .where("tcf.name = ?", "troublemaker_user_id")
              .where("u.username = ?", value)
          end,
        ]

        Reviewable.add_custom_filter(custom_filter)
        mod = Fabricate(:moderator)
        results = Reviewable.list_for(mod, additional_filters: { troublemaker: "badguy" })
        expect { results.first }.not_to raise_error
      end
    end
  end

  describe ".by_status" do
    it "includes reviewables with deleted targets when passing the reviewed status" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:deleted])

      expect(Reviewable.by_status(Reviewable.all, :reviewed)).to contain_exactly(reviewable)
    end
  end

  describe "#actions_for" do
    fab!(:reviewable) { Fabricate(:reviewable_queued_post) }
    fab!(:user)

    it "gets the bundles and actions for a reviewable" do
      actions = reviewable.actions_for(user.guardian)
      expect(actions.bundles.map(&:id)).to eq(%w[approve_post reject_post revise_and_reject_post])
      expect(actions.bundles.find { |b| b.id == "approve_post" }.actions.map(&:id)).to eq(
        ["approve_post"],
      )
      expect(actions.bundles.find { |b| b.id == "reject_post" }.actions.map(&:id)).to eq(
        ["reject_post"],
      )
      expect(actions.bundles.find { |b| b.id == "revise_and_reject_post" }.actions.map(&:id)).to eq(
        ["revise_and_reject_post"],
      )
    end

    describe "handling empty bundles" do
      class ReviewableTestRecord < Reviewable
        def build_actions(actions, guardian, args)
          actions.add(:approve_post) do |action|
            action.icon = "check"
            action.label = "reviewables.actions.approve_post.title"
          end
          actions.add_bundle("empty_bundle", icon: "xmark", label: "Empty Bundle")
        end
      end

      it "does not return empty bundles with no actions" do
        actions = ReviewableTestRecord.new.actions_for(user.guardian)
        expect(actions.bundles.map(&:id)).to eq(%w[approve_post])
        expect(actions.bundles.find { |b| b.id == "approve_post" }.actions.map(&:id)).to eq(
          ["approve_post"],
        )
      end
    end
  end

  describe "default actions" do
    let(:reviewable) { Reviewable.new }
    let(:actions) { Reviewable::Actions.new(reviewable, Guardian.new) }

    describe "#delete_user_actions" do
      it "adds a bundle with the delete_user action" do
        reviewable.delete_user_actions(actions)

        expect(actions.has?(:delete_user)).to be true
      end

      it "adds a bundle with the delete_user_block action" do
        reviewable.delete_user_actions(actions)

        expect(actions.has?(:delete_user_block)).to be true
      end
    end
  end

  describe ".unseen_reviewable_count" do
    fab!(:group)
    fab!(:category)
    fab!(:user)
    fab!(:admin_reviewable) { Fabricate(:reviewable, reviewable_by_moderator: false) }
    fab!(:mod_reviewable) { Fabricate(:reviewable, reviewable_by_moderator: true) }
    fab!(:category_moderation_group) { Fabricate(:category_moderation_group, category:, group:) }
    fab!(:group_reviewable) { Fabricate(:reviewable, reviewable_by_moderator: false, category:) }

    it "doesn't include reviewables that can't be seen by the user" do
      SiteSetting.enable_category_group_moderation = true
      expect(Reviewable.unseen_reviewable_count(user)).to eq(0)
      user.groups << group
      user.save!
      expect(Reviewable.unseen_reviewable_count(user)).to eq(1)
      user.update!(moderator: true)
      expect(Reviewable.unseen_reviewable_count(user)).to eq(2)
      user.update!(admin: true)
      expect(Reviewable.unseen_reviewable_count(user)).to eq(3)
    end

    it "returns count of unseen reviewables" do
      user.update!(admin: true)
      expect(Reviewable.unseen_reviewable_count(user)).to eq(3)
      user.update!(last_seen_reviewable_id: mod_reviewable.id)
      expect(Reviewable.unseen_reviewable_count(user)).to eq(1)
      user.update!(last_seen_reviewable_id: group_reviewable.id)
      expect(Reviewable.unseen_reviewable_count(user)).to eq(0)
    end

    it "doesn't include reviewables that are claimed by other users" do
      user.update!(admin: true)

      claimed_by_user = Fabricate(:reviewable, topic: Fabricate(:topic))
      Fabricate(:reviewable_claimed_topic, topic: claimed_by_user.topic, user: user)

      user2 = Fabricate(:user)
      claimed_by_user2 = Fabricate(:reviewable, topic: Fabricate(:topic))
      Fabricate(:reviewable_claimed_topic, topic: claimed_by_user2.topic, user: user2)

      unclaimed = Fabricate(:reviewable, topic: Fabricate(:topic))

      expect(Reviewable.unseen_reviewable_count(user)).to eq(5)
    end
  end
end

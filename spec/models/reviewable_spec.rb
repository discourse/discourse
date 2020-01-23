# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reviewable, type: :model do

  context ".create" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

    let(:reviewable) { Fabricate.build(:reviewable, created_by: admin) }

    it "can create a reviewable object" do
      expect(reviewable).to be_present
      expect(reviewable.pending?).to eq(true)
      expect(reviewable.created_by).to eq(admin)

      expect(reviewable.editable_for(Guardian.new(admin))).to be_blank

      expect(reviewable.payload).to be_present
      expect(reviewable.version).to eq(0)
      expect(reviewable.payload['name']).to eq('bandersnatch')
      expect(reviewable.payload['list']).to eq([1, 2, 3])
    end

    it "can add a target" do
      reviewable.target = user
      reviewable.save!

      expect(reviewable.target_type).to eq('User')
      expect(reviewable.target_id).to eq(user.id)
      expect(reviewable.target).to eq(user)
    end
  end

  context ".needs_review!" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

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
      moderator = Fabricate(:moderator)
      reviewable = PostActionCreator.spam(moderator, post).reviewable
      expect(reviewable.category).to eq(post.topic.category)
      new_cat = Fabricate(:category)
      PostRevisor.new(post).revise!(moderator, category_id: new_cat.id)
      expect(post.topic.reload.category).to eq(new_cat)
      expect(reviewable.reload.category).to eq(new_cat)
    end

    it "can create multiple objects with a NULL target" do
      r0 = ReviewableQueuedPost.needs_review!(created_by: admin, payload: { raw: 'hello world I am a post' })
      expect(r0).to be_present
      r0.update_column(:status, Reviewable.statuses[:approved])

      r1 = ReviewableQueuedPost.needs_review!(created_by: admin, payload: { raw: "another post's contents" })

      expect(ReviewableQueuedPost.count).to eq(2)
      expect(r1.id).not_to eq(r0.id)
      expect(r1.pending?).to eq(true)
      expect(r0.pending?).to eq(false)
    end
  end

  context ".list_for" do
    fab!(:user) { Fabricate(:user) }

    it "returns an empty list for nil user" do
      expect(Reviewable.list_for(nil)).to eq([])
    end

    context "with a pending item" do
      fab!(:post) { Fabricate(:post) }
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
        SiteSetting.enable_category_group_review = true
        group = Fabricate(:group)
        reviewable.reviewable_by_group_id = group.id
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
        SiteSetting.enable_category_group_review = false
        group = Fabricate(:group)
        reviewable.reviewable_by_group_id = group.id
        reviewable.save!

        GroupUser.create!(group_id: group.id, user_id: user.id)
        expect(Reviewable.list_for(user, status: :pending)).to be_blank
      end

      context 'Reviewing as an admin' do
        before { user.update_columns(moderator: false, admin: true) }

        it 'can filter by the target_created_by_id attribute' do
          different_reviewable = Fabricate(:reviewable)
          reviewables = Reviewable.list_for(user, username: different_reviewable.target_created_by.username)
          expect(reviewables).to include(different_reviewable)
          reviewables = Reviewable.list_for(user, username: user.username)
          expect(reviewables).not_to include(different_reviewable)
        end

        it 'can filter by the created_by_id attribute if there is no target' do
          qp = Fabricate(:reviewable_queued_post)
          reviewables = Reviewable.list_for(user, username: qp.created_by.username)
          expect(reviewables).to include(qp)
          reviewables = Reviewable.list_for(user, username: user.username)
          expect(reviewables).not_to include(qp)
        end

        it 'Does not filter by status when status parameter is set to all' do
          rejected_reviewable = Fabricate(:reviewable, target: post, status: Reviewable.statuses[:rejected])
          reviewables = Reviewable.list_for(user, status: :all)
          expect(reviewables).to match_array [reviewable, rejected_reviewable]
        end

        it "supports sorting" do
          r0 = Fabricate(:reviewable, score: 100, created_at: 3.months.ago)
          r1 = Fabricate(:reviewable, score: 999, created_at: 1.month.ago)

          list = Reviewable.list_for(user, sort_order: 'priority')
          expect(list[0].id).to eq(r1.id)
          expect(list[1].id).to eq(r0.id)

          list = Reviewable.list_for(user, sort_order: 'priority_asc')
          expect(list[0].id).to eq(r0.id)
          expect(list[1].id).to eq(r1.id)

          list = Reviewable.list_for(user, sort_order: 'created_at')
          expect(list[0].id).to eq(r1.id)
          expect(list[1].id).to eq(r0.id)

          list = Reviewable.list_for(user, sort_order: 'created_at_asc')
          expect(list[0].id).to eq(r0.id)
          expect(list[1].id).to eq(r1.id)
        end
      end
    end

    context "with a category restriction" do
      fab!(:category) { Fabricate(:category, read_restricted: true) }
      let(:topic) { Fabricate(:topic, category: category) }
      let(:post) { Fabricate(:post, topic: topic) }
      fab!(:moderator) { Fabricate(:moderator) }
      fab!(:admin) { Fabricate(:admin) }

      it "respects category id on the reviewable" do
        Group.refresh_automatic_group!(:staff)

        reviewable = ReviewableFlaggedPost.needs_review!(
          target: post,
          created_by: Fabricate(:user),
          reviewable_by_moderator: true
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

  it "valid_types returns the appropriate types" do
    expect(Reviewable.valid_type?('ReviewableUser')).to eq(true)
    expect(Reviewable.valid_type?('ReviewableQueuedPost')).to eq(true)
    expect(Reviewable.valid_type?('ReviewableFlaggedPost')).to eq(true)
    expect(Reviewable.valid_type?(nil)).to eq(false)
    expect(Reviewable.valid_type?("")).to eq(false)
    expect(Reviewable.valid_type?("Reviewable")).to eq(false)
    expect(Reviewable.valid_type?("ReviewableDoesntExist")).to eq(false)
    expect(Reviewable.valid_type?("User")).to eq(false)
  end

  context "events" do
    let!(:moderator) { Fabricate(:moderator) }
    let(:reviewable) { Fabricate(:reviewable) }

    it "triggers events on create, transition_to" do
      event = DiscourseEvent.track(:reviewable_created) { reviewable.save! }
      expect(event).to be_present
      expect(event[:params].first).to eq(reviewable)

      event = DiscourseEvent.track(:reviewable_transitioned_to) do
        reviewable.transition_to(:approved, moderator)
      end
      expect(event).to be_present
      expect(event[:params][0]).to eq(:approved)
      expect(event[:params][1]).to eq(reviewable)
    end
  end

  context "message bus notifications" do
    fab!(:moderator) { Fabricate(:moderator) }
    let(:post) { Fabricate(:post) }

    it "triggers a notification on create" do
      reviewable = Fabricate(:reviewable_queued_post)
      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
    end

    it "triggers a notification on update" do
      reviewable = PostActionCreator.spam(moderator, post).reviewable
      reviewable.perform(moderator, :disagree)

      expect { PostActionCreator.spam(Fabricate(:user), post) }
        .to change { reviewable.reload.status }
        .from(Reviewable.statuses[:rejected])
        .to(Reviewable.statuses[:pending])
        .and change { Jobs::NotifyReviewable.jobs.size }
        .by(1)
    end

    it "triggers a notification on pending -> approve" do
      reviewable = Fabricate(:reviewable_queued_post)

      expect do
        reviewable.perform(moderator, :approve_post)
      end.to change { Jobs::NotifyReviewable.jobs.size }.by(1)

      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
    end

    it "triggers a notification on pending -> reject" do
      reviewable = Fabricate(:reviewable_queued_post)

      expect do
        reviewable.perform(moderator, :reject_post)
      end.to change { Jobs::NotifyReviewable.jobs.size }.by(1)

      job = Jobs::NotifyReviewable.jobs.last

      expect(job["args"].first["reviewable_id"]).to eq(reviewable.id)
    end

    it "doesn't trigger a notification on approve -> reject" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:approved])

      expect do
        reviewable.perform(moderator, :reject_post)
      end.to_not change { Jobs::NotifyReviewable.jobs.size }
    end

    it "doesn't trigger a notification on reject -> approve" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:rejected])

      expect do
        reviewable.perform(moderator, :approve_post)
      end.to_not change { Jobs::NotifyReviewable.jobs.size }
    end
  end

  describe "flag_stats" do
    fab!(:user) { Fabricate(:user) }
    fab!(:post) { Fabricate(:post) }
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
      reviewable.perform(Discourse.system_user, :ignore)
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

  context ".score_required_to_hide_post" do

    it "will return the default visibility if it's higher" do
      Reviewable.set_priorities(low: 40.0, high: 100.0)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.score_required_to_hide_post).to eq(40.0)
    end

    it "returns a default if we can't calculated any percentiles" do
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:low]
      expect(Reviewable.score_required_to_hide_post).to eq(12.5)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:medium]
      expect(Reviewable.score_required_to_hide_post).to eq(8.33)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.score_required_to_hide_post).to eq(4.16)
    end

    it "returns a fraction of the high percentile" do
      Reviewable.set_priorities(high: 100.0)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:disabled]
      expect(Reviewable.score_required_to_hide_post.to_f.truncate(2)).to eq(Float::MAX)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:low]
      expect(Reviewable.score_required_to_hide_post.to_f.truncate(2)).to eq(100.0)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:medium]
      expect(Reviewable.score_required_to_hide_post.to_f.truncate(2)).to eq(66.66)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.score_required_to_hide_post.to_f.truncate(2)).to eq(33.33)
    end
  end

  context ".spam_score_to_silence_new_user" do
    it "returns a default value if we can't calculated any percentiles" do
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:low]
      expect(Reviewable.spam_score_to_silence_new_user).to eq(7.5)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:medium]
      expect(Reviewable.spam_score_to_silence_new_user).to eq(4.99)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.spam_score_to_silence_new_user).to eq(2.49)
    end

    it "returns a fraction of the high percentile" do
      Reviewable.set_priorities(high: 100.0)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:disabled]
      expect(Reviewable.spam_score_to_silence_new_user.to_f).to eq(Float::MAX)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:low]
      expect(Reviewable.spam_score_to_silence_new_user.to_f).to eq(60.0)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:medium]
      expect(Reviewable.spam_score_to_silence_new_user.to_f).to eq(39.99)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.spam_score_to_silence_new_user.to_f).to eq(19.99)
    end
  end

  context ".score_to_auto_close_topic" do

    it "returns the default if we can't calculated any percentiles" do
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:low]
      expect(Reviewable.score_to_auto_close_topic).to eq(31.25)
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:medium]
      expect(Reviewable.score_to_auto_close_topic).to eq(20.83)
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.score_to_auto_close_topic).to eq(10.41)
    end

    it "returns a fraction of the high percentile" do
      Reviewable.set_priorities(high: 100.0)
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:disabled]
      expect(Reviewable.score_to_auto_close_topic.to_f.truncate(2)).to eq(Float::MAX)
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:low]
      expect(Reviewable.score_to_auto_close_topic.to_f.truncate(2)).to eq(250.0)
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:medium]
      expect(Reviewable.score_to_auto_close_topic.to_f.truncate(2)).to eq(166.66)
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivity[:high]
      expect(Reviewable.score_to_auto_close_topic.to_f.truncate(2)).to eq(83.33)
    end
  end

  context "priorities" do
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
      SiteSetting.reviewable_default_visibility = 'medium'
      expect(Reviewable.min_score_for_priority).to eq(12.3)
      SiteSetting.reviewable_default_visibility = 'high'
      expect(Reviewable.min_score_for_priority).to eq(45.6)
    end
  end

  context "custom filters" do
    after do
      Reviewable.clear_custom_filters!
    end

    it 'correctly add a new filter' do
      Reviewable.add_custom_filter([:assigned_to, Proc.new { |results, value| results }])

      expect(Reviewable.custom_filters.size).to eq(1)
    end

    it 'applies the custom filter' do
      admin = Fabricate(:admin)
      first_reviewable = Fabricate(:reviewable)
      second_reviewable = Fabricate(:reviewable)
      custom_filter = [:target_id, Proc.new { |results, value| results.where(target_id: value) }]
      Reviewable.add_custom_filter(custom_filter)

      results = Reviewable.list_for(admin, additional_filters: { target_id: first_reviewable.target_id })

      expect(results.size).to eq(1)
      expect(results.first).to eq first_reviewable
    end
  end

  describe '.by_status' do
    it 'includes reviewables with deleted targets when passing the reviewed status' do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:deleted])

      expect(Reviewable.by_status(Reviewable.all, :reviewed)).to contain_exactly(reviewable)
    end
  end
end

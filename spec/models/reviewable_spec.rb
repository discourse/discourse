require 'rails_helper'

RSpec.describe Reviewable, type: :model do

  context ".create" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }

    let(:reviewable) { Fabricate.build(:reviewable, created_by: admin) }
    let(:queued_post) { Fabricate.build(:reviewable_queued_post) }

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
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }

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
    let(:user) { Fabricate(:user) }

    it "returns an empty list for nil user" do
      expect(Reviewable.list_for(nil)).to eq([])
    end

    context "with a pending item" do
      let(:post) { Fabricate(:post) }
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

      it 'Let us filter by the target_created_by_id attribute' do
        user.update_columns(moderator: false, admin: true)
        different_user_reviewable = Fabricate(:reviewable)

        reviewables = Reviewable.list_for(
          user, target_created_by_id: different_user_reviewable.target_created_by_id
        )

        expect(reviewables).to match_array [different_user_reviewable]
      end

      it 'Excludes reviewable that do not match with the created_by_id' do
        user.update_columns(moderator: false, admin: true)
        unknown_target_created_by_id = -99
        filtered_reviewable = reviewable

        reviewables = Reviewable.list_for(
          user, target_created_by_id: unknown_target_created_by_id
        )

        expect(reviewables).not_to include filtered_reviewable
      end
    end

    context "with a category restriction" do
      let(:category) { Fabricate(:category, read_restricted: true) }
      let(:topic) { Fabricate(:topic, category: category) }
      let(:post) { Fabricate(:post, topic: topic) }
      let!(:moderator) { Fabricate(:moderator) }
      let(:admin) { Fabricate(:admin) }

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
    let(:moderator) { Fabricate(:moderator) }

    it "triggers a notification on create" do
      Jobs.expects(:enqueue).with(:notify_reviewable, has_key(:reviewable_id))
      Fabricate(:reviewable_queued_post)
    end

    it "triggers a notification on pending -> approve" do
      reviewable = Fabricate(:reviewable_queued_post)
      Jobs.expects(:enqueue).with(:notify_reviewable, has_key(:reviewable_id))
      reviewable.perform(moderator, :approve)
    end

    it "triggers a notification on pending -> reject" do
      reviewable = Fabricate(:reviewable_queued_post)
      Jobs.expects(:enqueue).with(:notify_reviewable, has_key(:reviewable_id))
      reviewable.perform(moderator, :reject)
    end

    it "doesn't trigger a notification on approve -> reject" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:approved])
      Jobs.expects(:enqueue).with(:notify_reviewable, has_key(:reviewable_id)).never
      reviewable.perform(moderator, :reject)
    end

    it "doesn't trigger a notification on reject -> approve" do
      reviewable = Fabricate(:reviewable_queued_post, status: Reviewable.statuses[:approved])
      Jobs.expects(:enqueue).with(:notify_reviewable, has_key(:reviewable_id)).never
      reviewable.perform(moderator, :reject)
    end
  end

  describe "flag_stats" do
    let(:user) { Fabricate(:user) }
    let(:post) { Fabricate(:post) }
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
end

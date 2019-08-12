# frozen_string_literal: true

require 'rails_helper'

describe PostActionCreator do
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post) }
  let(:like_type_id) { PostActionType.types[:like] }

  describe "rate limits" do
    before do
      RateLimiter.clear_all!
      RateLimiter.enable
    end

    it "limits redo/undo" do
      PostActionCreator.like(user, post)
      PostActionDestroyer.destroy(user, post, :like)
      PostActionCreator.like(user, post)
      PostActionDestroyer.destroy(user, post, :like)

      expect {
        PostActionCreator.like(user, post)
      }.to raise_error(RateLimiter::LimitExceeded)
    end
  end

  describe "messaging" do

    it "doesn't generate title longer than 255 characters" do
      topic = Fabricate(:topic, title: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc sit amet rutrum neque. Pellentesque suscipit vehicula facilisis. Phasellus lacus sapien, aliquam nec convallis sit amet, vestibulum laoreet ante. Curabitur et pellentesque tortor. Donec non.")
      post = Fabricate(:post, topic: topic)

      expect(PostActionCreator.notify_user(user, post, "WAT")).to be_success
    end

    it "creates a pm to mods if selected" do
      result = PostActionCreator.notify_moderators(user, post, "this is my special message")
      expect(result).to be_success
      post_action = result.post_action
      expect(post_action.related_post).to be_present
      expect(post_action.related_post.raw).to include("this is my special message")
    end

    it "sends an pm to user if selected" do
      result = PostActionCreator.notify_user(user, post, "another special message")
      expect(result).to be_success
      post_action = result.post_action
      expect(post_action.related_post).to be_present
      expect(post_action.related_post.raw).to include("another special message")
    end
  end

  describe 'perform' do
    it 'creates a post action' do
      result = PostActionCreator.new(user, post, like_type_id).perform
      expect(result.success).to eq(true)
      expect(result.post_action).to be_present
      expect(result.post_action.user).to eq(user)
      expect(result.post_action.post).to eq(post)
      expect(result.post_action.post_action_type_id).to eq(like_type_id)
    end

    it 'does not create an invalid post action' do
      result = PostActionCreator.new(user, nil, like_type_id).perform
      expect(result.failed?).to eq(true)
    end

    it 'does not create a double like notification' do
      PostActionNotifier.enable
      post.user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:always])

      expect(PostActionCreator.new(user, post, like_type_id).perform.success).to eq(true)
      expect(PostActionDestroyer.new(user, post, like_type_id).perform.success).to eq(true)
      expect(PostActionCreator.new(user, post, like_type_id).perform.success).to eq(true)

      notification = Notification.last
      notification_data = JSON.parse(notification.data)
      expect(notification_data['display_username']).to eq(user.username)
      expect(notification_data['username2']).to eq(nil)
    end
  end

  context "flags" do
    it "will create a reviewable if one does not exist" do
      result = PostActionCreator.create(user, post, :inappropriate)
      expect(result.success?).to eq(true)

      reviewable = result.reviewable
      expect(reviewable).to be_pending
      expect(reviewable.created_by).to eq(user)
      expect(reviewable.type).to eq("ReviewableFlaggedPost")
      expect(reviewable.target_created_by_id).to eq(post.user_id)

      expect(reviewable.reviewable_scores.count).to eq(1)
      score = reviewable.reviewable_scores.find_by(user: user)
      expect(score).to be_present
      expect(score.reviewed_by).to be_blank
      expect(score.reviewed_at).to be_blank
    end

    context "existing reviewable" do
      let!(:reviewable) {
        PostActionCreator.create(Fabricate(:user), post, :inappropriate).reviewable
      }

      it "appends to an existing reviewable if exists" do
        result = PostActionCreator.create(user, post, :inappropriate)
        expect(result.success?).to eq(true)

        expect(result.reviewable).to eq(reviewable)
        expect(reviewable.reviewable_scores.count).to eq(2)
        score = reviewable.reviewable_scores.find_by(user: user)
        expect(score).to be_present
        expect(score.reviewed_by).to be_blank
        expect(score.reviewed_at).to be_blank
      end
    end
  end

  context "take_action" do
    before do
      PostActionCreator.create(Fabricate(:user), post, :inappropriate)
    end

    it "will agree with the old reviewable" do
      reviewable = PostActionCreator.new(
        Fabricate(:moderator),
        post,
        PostActionType.types[:spam],
        take_action: true
      ).perform.reviewable
      scores = reviewable.reviewable_scores
      expect(scores[0]).to be_agreed
      expect(scores[1]).to be_agreed
      expect(reviewable.reload).to be_approved
    end
  end
end
